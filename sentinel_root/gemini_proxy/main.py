import os
import json
import urllib.request
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app) # Allow cross-origin requests from Flutter Web

API_KEY = os.environ.get("GEMINI_API_KEY", "")
if not API_KEY:
    print("WARNING: GEMINI_API_KEY environment variable is not set.")

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "operational"}), 200

@app.route("/list_models", methods=["GET"])
def list_models():
    """Diagnostic endpoint: lists all models available for this API key."""
    try:
        models_found = []
        for api_ver in ["v1beta", "v1"]:
            url = f"https://generativelanguage.googleapis.com/{api_ver}/models?key={API_KEY}"
            req = urllib.request.Request(url)
            response = urllib.request.urlopen(req)
            result = json.loads(response.read().decode('utf-8'))
            for m in result.get("models", []):
                methods = m.get("supportedGenerationMethods", [])
                if "generateContent" in methods:
                    models_found.append({
                        "name": m["name"],
                        "displayName": m.get("displayName", ""),
                        "api_version": api_ver
                    })
        return jsonify({"available_models": models_found}), 200
    except Exception as e:
        err_msg = str(e)
        if hasattr(e, 'read'):
            try:
                err_msg += " | " + e.read().decode('utf-8')
            except:
                pass
        return jsonify({"error": err_msg}), 500

@app.route("/generate_report", methods=["POST"])
def generate_report():
    try:
        data = request.json
        if not data:
            return jsonify({"error": "No JSON payload provided"}), 400

        transaction_id = data.get("transaction_id", "UNKNOWN")
        ptr = data.get("ptr", "UNKNOWN")
        jitter_ms = data.get("jitter_ms", "UNKNOWN")
        status = data.get("status", "UNKNOWN")

        prompt = f"""
        You are 'Sentinel AI', an autonomous L6 cybersecurity analyst for the Central Bank.
        A financial transaction has just been BLOCKED by the High-Frequency C++ Sieve Engine.

        TRANSACTION TELEMETRY:
        - Transaction ID: {transaction_id}
        - Propensity To Risk (PTR): {ptr} (Threshold is 0.85)
        - Jitter Variance: {jitter_ms}ms (Low jitter < 100ms indicates programmatic bot execution)
        - Sieve Verdict: {status}

        Generate a highly verbose, professional, and technical Threat Intelligence Report (2-3 short paragraphs).
        Format the output using strict markdown.
        
        Requirements:
        1. State the critical reason for interception (e.g., automated execution patterns, ML risk threshold exceeded).
        2. Provide a brief analysis of the attack vector (e.g., coordinated mule ring, credential stuffing, programmatic execution).
        3. End with a recommended SOC action (e.g., 'Quarantine originating IP block', 'Flag linked accounts for review').
        
        DO NOT say "Here is the report" or use introductory fluff. Just output the raw professional report.
        """

        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={API_KEY}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}]
        }
        
        req = urllib.request.Request(
            url, 
            data=json.dumps(payload).encode('utf-8'), 
            headers={'Content-Type': 'application/json'}
        )
        
        response = urllib.request.urlopen(req)
        result = json.loads(response.read().decode('utf-8'))
        
        report_text = result["candidates"][0]["content"]["parts"][0]["text"]

        return jsonify({
            "report": report_text,
            "transaction_id": transaction_id
        }), 200

    except Exception as e:
        err_msg = str(e)
        if hasattr(e, 'read'):
            try:
                err_msg += " | Body: " + e.read().decode('utf-8')
            except:
                pass
        print(f"Error generating report: {err_msg}")
        return jsonify({"error": err_msg}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
