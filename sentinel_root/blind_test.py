import urllib.request, json, random, time

# ═══════════════════════════════════════════════════════════════════════════════
#  BLIND RANDOM TEST — Sentinel-V1 Backend
#
#  Rules:
#  1. UPI IDs are completely invented right now — no prior state
#  2. Feature values (ptr, jitter_ms) are set to realistic ranges based on
#     actual UPI fraud patterns, NOT hardcoded to cheat
#  3. The system must detect the rings purely from telemetry behavior
#
#  Realistic feature ranges (from UPI fraud research):
#    MULE transaction:  ptr=0.90-0.99,  jitter_ms=20-90   (rapid pass-through)
#    LEGIT transaction: ptr=0.05-0.40,  jitter_ms=700-2500 (human spending)
#
#  Expected outcome:
#    - BLOCKED: any transaction where ptr > 0.85 OR jitter < 100
#    - Ring A detected: chain through the first set of mule receivers
#    - Ring B detected: chain through the second set of mule receivers
#    - Legit transactions: ALLOWED, Rings=0, centrality low
# ═══════════════════════════════════════════════════════════════════════════════

URL = 'https://sentinel-v1-backend-647109791978.asia-south1.run.app/intercept'

def post(txn):
    data = json.dumps(txn).encode("utf-8")
    req = urllib.request.Request(URL, data=data, headers={"Content-Type": "application/json"})
    resp = urllib.request.urlopen(req, timeout=15)
    return json.loads(resp.read().decode("utf-8"))

# ─────────────────────────────────────────────────────────────────────────────
#  TRANSACTION SET — COMPLETELY BLIND UPI IDs
#
#  Ring A (UPI banking fraud chain):
#    Victims → j.fernandez92@okaxis → p.xavier.trades@ybl → offshore.remit7@kotak
#
#  Ring B (Investment scam chain):
#    Victims → lucky.draw99@oksbi → clearing.fast@okicici → wallet.exit22@ybl
#
#  Legit: random people paying for groceries, rent, utilities
# ─────────────────────────────────────────────────────────────────────────────

txns = [
    # LEGIT — morning coffee, groceries, OTT subscription
    {"transaction_id": "BT-00001", "sender_upi": "ramesh.b2004@oksbi",       "receiver_upi": "starbucks.india@hdfcbank", "jitter_ms": 1843, "ptr": 0.08},
    {"transaction_id": "BT-00002", "sender_upi": "leena.nk@okicici",          "receiver_upi": "reliance.fresh@ybl",       "jitter_ms": 2210, "ptr": 0.21},

    # RING A — victim 1 sends to mule layer 1
    # ptr=0.94: nearly all money will pass through. jitter=55ms: automated
    {"transaction_id": "BT-00003", "sender_upi": "chandni.v.1991@okaxis",    "receiver_upi": "j.fernandez92@okaxis",     "jitter_ms": 55,   "ptr": 0.94},

    # RING B — victim 1 sends to mule layer 1 (different chain)
    {"transaction_id": "BT-00004", "sender_upi": "tarun.sood88@ybl",         "receiver_upi": "lucky.draw99@oksbi",       "jitter_ms": 48,   "ptr": 0.96},

    # LEGIT — utility bill, rent
    {"transaction_id": "BT-00005", "sender_upi": "geeta.pillai@oksbi",       "receiver_upi": "bescom.electricity@sbi",   "jitter_ms": 1560, "ptr": 0.13},

    # RING A — mule layer 1 → mule layer 2 (pass-through)
    # ptr=0.97: almost pure pass-through. jitter=31ms: bot speed
    {"transaction_id": "BT-00006", "sender_upi": "j.fernandez92@okaxis",     "receiver_upi": "p.xavier.trades@ybl",      "jitter_ms": 31,   "ptr": 0.97},

    # RING B — mule layer 1 → mule layer 2
    {"transaction_id": "BT-00007", "sender_upi": "lucky.draw99@oksbi",       "receiver_upi": "clearing.fast@okicici",    "jitter_ms": 27,   "ptr": 0.98},

    # LEGIT — food delivery
    {"transaction_id": "BT-00008", "sender_upi": "mukesh.r99@ybl",           "receiver_upi": "swiggy.orders@paytm",      "jitter_ms": 1290, "ptr": 0.17},

    # RING A — victim 2 feeds mule layer 1 again (strengthens the node)
    {"transaction_id": "BT-00009", "sender_upi": "preethi.anand@okicici",    "receiver_upi": "j.fernandez92@okaxis",     "jitter_ms": 62,   "ptr": 0.92},

    # RING A — mule layer 2 → exit node (offshore)
    {"transaction_id": "BT-00010", "sender_upi": "p.xavier.trades@ybl",      "receiver_upi": "offshore.remit7@kotak",    "jitter_ms": 29,   "ptr": 0.99},

    # RING B — mule layer 2 → exit node
    {"transaction_id": "BT-00011", "sender_upi": "clearing.fast@okicici",    "receiver_upi": "wallet.exit22@ybl",        "jitter_ms": 24,   "ptr": 0.99},

    # LEGIT — movie tickets
    {"transaction_id": "BT-00012", "sender_upi": "anjali.desai@okaxis",      "receiver_upi": "bookmyshow@hdfcbank",      "jitter_ms": 1750, "ptr": 0.09},

    # RING A — victim 3 adds another edge into mule layer 1
    {"transaction_id": "BT-00013", "sender_upi": "devraj.m.83@oksbi",        "receiver_upi": "j.fernandez92@okaxis",     "jitter_ms": 44,   "ptr": 0.93},

    # RING B — victim 2 adds another edge into mule layer 1
    {"transaction_id": "BT-00014", "sender_upi": "farida.khan91@okaxis",     "receiver_upi": "lucky.draw99@oksbi",       "jitter_ms": 51,   "ptr": 0.91},

    # RING A — mule layer 1 → mule layer 2 again (repeat pass-through)
    {"transaction_id": "BT-00015", "sender_upi": "j.fernandez92@okaxis",     "receiver_upi": "p.xavier.trades@ybl",      "jitter_ms": 33,   "ptr": 0.96},

    # RING B — mule layer 1 → mule layer 2 again
    {"transaction_id": "BT-00016", "sender_upi": "lucky.draw99@oksbi",       "receiver_upi": "clearing.fast@okicici",    "jitter_ms": 28,   "ptr": 0.97},

    # LEGIT — insurance premium
    {"transaction_id": "BT-00017", "sender_upi": "harish.ts@ybl",            "receiver_upi": "licindia.premium@sbi",     "jitter_ms": 2100, "ptr": 0.06},

    # RING A — mule layer 2 → exit again (repeat)
    {"transaction_id": "BT-00018", "sender_upi": "p.xavier.trades@ybl",      "receiver_upi": "offshore.remit7@kotak",    "jitter_ms": 26,   "ptr": 0.98},

    # RING B — mule layer 2 → exit again (repeat)
    {"transaction_id": "BT-00019", "sender_upi": "clearing.fast@okicici",    "receiver_upi": "wallet.exit22@ybl",        "jitter_ms": 25,   "ptr": 0.99},

    # LEGIT — final normal transaction
    {"transaction_id": "BT-00020", "sender_upi": "sundarram.p@okicici",      "receiver_upi": "amazon.pay@apl",           "jitter_ms": 1640, "ptr": 0.19},
]

# ─────────────────────────────────────────────────────────────────────────────
#  EXPECTED RESULTS (pre-computed by hand for verification)
# ─────────────────────────────────────────────────────────────────────────────
EXPECTED = {
    "BT-00001": "allowed", "BT-00002": "allowed",
    "BT-00003": "blocked", "BT-00004": "blocked",
    "BT-00005": "allowed",
    "BT-00006": "blocked", "BT-00007": "blocked",
    "BT-00008": "allowed",
    "BT-00009": "blocked", "BT-00010": "blocked", "BT-00011": "blocked",
    "BT-00012": "allowed",
    "BT-00013": "blocked", "BT-00014": "blocked", "BT-00015": "blocked",
    "BT-00016": "blocked",
    "BT-00017": "allowed",
    "BT-00018": "blocked", "BT-00019": "blocked",
    "BT-00020": "allowed",
}

EXPECTED_RING_A = ["p.xavier.trades@ybl", "offshore.remit7@kotak"]  # Mule receivers only
EXPECTED_RING_B = ["clearing.fast@okicici", "wallet.exit22@ybl"]     # Mule receivers only
# Note: j.fernandez92 and lucky.draw99 are also receivers so should appear too

print("=" * 100)
print("SENTINEL BLIND RANDOM TEST — COMPLETELY UNSEEN UPI IDs")
print("Detection based purely on ptr + jitter telemetry, NOT on UPI ID identity")
print("=" * 100)
print("")

correct = 0
wrong = 0
final_rings = []

for i, tx in enumerate(txns):
    try:
        result = post(tx)
        status = result.get("status", "?")
        ml = result.get("ml_risk_score", 0)
        cent = result.get("centrality_score", 0)
        rings = result.get("rings", [])
        expected = EXPECTED[tx["transaction_id"]]

        match = "✅" if status == expected else "❌"
        if status == expected:
            correct += 1
        else:
            wrong += 1

        if rings:  # Only update when rings are present — don't overwrite with [] from ALLOWED txns
            final_rings = rings

        print("[%02d] %s %s | %-7s (expected %-7s) | ML=%.3f | Cent=%.3f | Rings=%d | %s → %s" % (
            i+1, match, tx["transaction_id"],
            status.upper(), expected.upper(),
            ml, cent, len(rings),
            tx["sender_upi"].split("@")[0],
            tx["receiver_upi"].split("@")[0]
        ))

    except Exception as e:
        print("[%02d] ❌ %s | ERROR: %s" % (i+1, tx["transaction_id"], e))
        wrong += 1

print("")
print("=" * 100)
print("ACCURACY: %d/%d correct (%.1f%%)" % (correct, len(txns), correct/len(txns)*100))
print("")

# Final ring summary
if final_rings:
    print("FINAL DETECTED RINGS:")
    for ri, ring in enumerate(final_rings):
        chain = ring.get("chain", [])
        evidence = ring.get("evidence_txn_ids", [])
        print("  Ring #%d (%d nodes): %s" % (ri+1, len(chain), " → ".join(chain)))
        print("  Evidence txns:  %s" % evidence)
        print("")
    
    # Verify ring A and B are separate
    if len(final_rings) >= 2:
        all_chains = [set(r.get("chain",[])) for r in final_rings]
        overlap = all_chains[0] & all_chains[1]
        if overlap:
            print("⚠️  OVERLAP between rings: %s — rings are NOT cleanly separated" % overlap)
        else:
            print("✅ RINGS ARE CLEANLY SEPARATED — zero node overlap")
else:
    print("⚠️  NO RINGS DETECTED — check if backend is running detect_rings()")

print("=" * 100)
