import urllib.request, json

url = 'https://sentinel-v1-backend-647109791978.asia-south1.run.app/intercept'

# ═══════════════════════════════════════════════════════════════
#  TEST SCENARIO: Two independent mule rings + legitimate traffic
#
#  Ring A (UPI fraud → hawala):
#    victims → ravi.kumar92@okaxis → deepak.trades@ybl → fx.remit.global@kotak
#
#  Ring B (crypto scam):
#    victims → sunita.crypto@oksbi → nikhil.p2p@ybl → binance.deposit@kotak
#
#  Legitimate traffic interspersed throughout.
# ═══════════════════════════════════════════════════════════════

txns = [
    # Legit
    {"transaction_id": "TXN-40001", "sender_upi": "anita.sharma@okaxis", "receiver_upi": "flipkart.payments@ybl", "jitter_ms": 1200, "ptr": 0.15},
    
    # Ring A: victim1 -> mule1
    {"transaction_id": "TXN-40002", "sender_upi": "priya.iyer@okicici", "receiver_upi": "ravi.kumar92@okaxis", "jitter_ms": 42, "ptr": 0.93},
    
    # Ring B: victim1 -> mule1 (DIFFERENT ring)
    {"transaction_id": "TXN-40003", "sender_upi": "arjun.mehta@okaxis", "receiver_upi": "sunita.crypto@oksbi", "jitter_ms": 38, "ptr": 0.96},
    
    # Legit
    {"transaction_id": "TXN-40004", "sender_upi": "sanjay.mehra@ybl", "receiver_upi": "amazon.pay@apl", "jitter_ms": 1350, "ptr": 0.18},
    
    # Ring A: mule1 -> mule2
    {"transaction_id": "TXN-40005", "sender_upi": "ravi.kumar92@okaxis", "receiver_upi": "deepak.trades@ybl", "jitter_ms": 35, "ptr": 0.97},
    
    # Ring B: mule1 -> mule2 (DIFFERENT ring)
    {"transaction_id": "TXN-40006", "sender_upi": "sunita.crypto@oksbi", "receiver_upi": "nikhil.p2p@ybl", "jitter_ms": 33, "ptr": 0.98},
    
    # Legit
    {"transaction_id": "TXN-40007", "sender_upi": "kavita.singh@ybl", "receiver_upi": "zomato.payments@hdfcbank", "jitter_ms": 1450, "ptr": 0.10},
    
    # Ring A: mule2 -> exit
    {"transaction_id": "TXN-40008", "sender_upi": "deepak.trades@ybl", "receiver_upi": "fx.remit.global@kotak", "jitter_ms": 31, "ptr": 0.99},
    
    # Ring B: mule2 -> exit
    {"transaction_id": "TXN-40009", "sender_upi": "nikhil.p2p@ybl", "receiver_upi": "binance.deposit@kotak", "jitter_ms": 29, "ptr": 0.99},
    
    # Ring A: victim2 -> mule1 (strengthens ring A)
    {"transaction_id": "TXN-40010", "sender_upi": "suresh.reddy@okaxis", "receiver_upi": "ravi.kumar92@okaxis", "jitter_ms": 40, "ptr": 0.92},
    
    # Ring B: victim2 -> mule1 (strengthens ring B)
    {"transaction_id": "TXN-40011", "sender_upi": "meena.krishnan@okicici", "receiver_upi": "sunita.crypto@oksbi", "jitter_ms": 37, "ptr": 0.94},
    
    # Legit
    {"transaction_id": "TXN-40012", "sender_upi": "rahul.deshpande@oksbi", "receiver_upi": "irctc.tickets@sbi", "jitter_ms": 1250, "ptr": 0.12},
    
    # Ring A: victim3 -> mule1 (even more density)
    {"transaction_id": "TXN-40013", "sender_upi": "amit.joshi@okicici", "receiver_upi": "ravi.kumar92@okaxis", "jitter_ms": 44, "ptr": 0.91},
    
    # Ring A: mule1 -> mule2 again
    {"transaction_id": "TXN-40014", "sender_upi": "ravi.kumar92@okaxis", "receiver_upi": "deepak.trades@ybl", "jitter_ms": 36, "ptr": 0.96},
    
    # Ring B: victim3 -> mule1
    {"transaction_id": "TXN-40015", "sender_upi": "dinesh.pillai@ybl", "receiver_upi": "sunita.crypto@oksbi", "jitter_ms": 41, "ptr": 0.93},
    
    # Ring B: mule1 -> mule2 again
    {"transaction_id": "TXN-40016", "sender_upi": "sunita.crypto@oksbi", "receiver_upi": "nikhil.p2p@ybl", "jitter_ms": 34, "ptr": 0.97},
    
    # Ring A: mule2 -> exit again
    {"transaction_id": "TXN-40017", "sender_upi": "deepak.trades@ybl", "receiver_upi": "fx.remit.global@kotak", "jitter_ms": 32, "ptr": 0.98},
    
    # Ring B: mule2 -> exit again
    {"transaction_id": "TXN-40018", "sender_upi": "nikhil.p2p@ybl", "receiver_upi": "binance.deposit@kotak", "jitter_ms": 30, "ptr": 0.99},
    
    # Legit
    {"transaction_id": "TXN-40019", "sender_upi": "arun.nair@oksbi", "receiver_upi": "phonepe.merchant@ybl", "jitter_ms": 1300, "ptr": 0.16},
    
    # Legit
    {"transaction_id": "TXN-40020", "sender_upi": "karthik.menon@okicici", "receiver_upi": "uber.rides@okaxis", "jitter_ms": 1100, "ptr": 0.24},
]

print("=" * 90)
print("SENTINEL DRY RUN — MULTI-RING TEST")
print("=" * 90)
print("")

for i, tx in enumerate(txns):
    data = json.dumps(tx).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        result = json.loads(resp.read().decode("utf-8"))
        status = result.get("status", "?")
        ml = result.get("ml_risk_score", 0)
        cent = result.get("centrality_score", 0)
        rings = result.get("rings", [])
        
        ring_count = len(rings) if rings else 0

        print("[%02d] %-10s | %-7s | ML=%.3f | Cent=%.3f | Rings=%d | %s -> %s" % (
            i+1, tx["transaction_id"], status.upper(), ml, cent, ring_count,
            tx.get("sender_upi",""), tx.get("receiver_upi","")
        ))
        
        if ring_count > 0:
            for ri, ring in enumerate(rings):
                chain = ring.get("chain", [])
                evidence = ring.get("evidence_txn_ids", [])
                print("         RING #%d: %s" % (ri+1, " -> ".join(chain)))
                print("         EVIDENCE: %s" % evidence)
    except Exception as e:
        print("[%02d] %-10s | ERROR: %s" % (i+1, tx["transaction_id"], e))

print("")
print("=" * 90)
print("TEST COMPLETE")
print("=" * 90)
