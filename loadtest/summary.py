import csv
import json
import os
import sys

prefix = sys.argv[1]

with open(f"{prefix}_stats.csv", newline="") as f:
    rows = {row["Name"]: row for row in csv.DictReader(f)}

total = rows["Aggregated"]
requests = int(total["Request Count"])
failures = int(total["Failure Count"])

print(f"Запитів:        {requests}")
print(f"Помилок:        {failures} ({100 * failures / requests:.2f}%)")
print(f"Запитів за с:   {float(total['Requests/s']):.1f}")
print(f"Латентність p50 / p95 / p99, мс: {total['50%']} / {total['95%']} / {total['99%']}")

cache_file = f"{prefix}_cache.json"
if os.path.exists(cache_file):
    with open(cache_file) as f:
        cache = json.load(f)
    hits, misses = cache.get("HIT", 0), cache.get("MISS", 0)
    if hits + misses:
        print(f"Кеш GET /posts: HIT {hits}, MISS {misses}, влучань {100 * hits / (hits + misses):.1f}%")
