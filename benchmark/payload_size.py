"""Compares JSON, MessagePack and MessagePack + Brotli for odds-like payloads.

Prints wire size, median decode time and transfer time on a 750 kbit/s link.

    pip install msgpack brotli
    python benchmark/payload_size.py
"""

import json
import random
import statistics
import time

import brotli
import msgpack

random.seed(42)

BANDWIDTH_BYTES_PER_SECOND = 750_000 / 8
RUNS = 300


def outcome(i: int) -> dict:
    return {
        "id": random.randint(10**8, 10**9),
        "name": ["1", "X", "2", "Over", "Under"][i % 5],
        "odds": round(random.uniform(1.05, 9.5), 2),
        "isBlocked": False,
        "updatedAt": 1_760_000_000_000 + i,
    }


def market(i: int) -> dict:
    return {
        "id": random.randint(10**6, 10**7),
        "typeId": i % 40,
        "name": f"Total {i % 7 + 0.5}",
        "status": "Active",
        "outcomes": [outcome(j) for j in range(3)],
    }


def event(i: int) -> dict:
    return {
        "eventId": random.randint(10**7, 10**8),
        "sportId": i % 12,
        "home": f"Team {i}A",
        "away": f"Team {i}B",
        "score": "1:0",
        "minute": random.randint(1, 90),
        "markets": [market(j) for j in range(8)],
    }


def median_us(fn, arg) -> float:
    samples = []
    for _ in range(RUNS):
        start = time.perf_counter()
        fn(arg)
        samples.append((time.perf_counter() - start) * 1e6)
    return statistics.median(samples)


def main() -> None:
    cases = [("delta, 1 event", 1), ("live list, 20 events", 20), ("snapshot, 200 events", 200)]
    header = f"{'case':<22}{'format':<14}{'bytes':>10}{'decode µs':>12}{'3G ms':>9}"
    print(header)
    print("-" * len(header))

    for label, count in cases:
        arguments = [[event(i) for i in range(count)]]

        as_json = (json.dumps({"type": 1, "target": "OddsUpdated", "arguments": arguments}, separators=(",", ":")) + "\x1e").encode()
        as_msgpack = msgpack.packb([1, {}, None, "OddsUpdated", arguments])
        as_brotli = msgpack.packb([1, {}, None, "OddsUpdated", 1, brotli.compress(msgpack.packb(arguments), quality=5)])

        rows = [
            ("json", as_json, lambda b: json.loads(b[:-1])),
            ("msgpack", as_msgpack, msgpack.unpackb),
            ("msgpack+br", as_brotli, lambda b: msgpack.unpackb(brotli.decompress(msgpack.unpackb(b)[5]))),
        ]
        for name, data, decode in rows:
            transfer_ms = len(data) / BANDWIDTH_BYTES_PER_SECOND * 1000
            print(f"{label:<22}{name:<14}{len(data):>10}{median_us(decode, data):>12.0f}{transfer_ms:>9.0f}")
        print()


if __name__ == "__main__":
    main()
