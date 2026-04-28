#include "firestore_client.hpp"
#include <curl/curl.h>
#include <iostream>

FirestoreClient::FirestoreClient(std::string_view project_id) : project_id_(project_id) {
    // curl_global_init is called once at process start in main() — do NOT call here.
}

void FirestoreClient::push_alert(std::string_view alert_json) {
    CURL* curl = curl_easy_init();
    if (curl) {
        std::string url = "https://firestore.googleapis.com/v1/projects/" + project_id_ + "/databases/(default)/documents/live_alerts";
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        
        struct curl_slist* headers = NULL;
        headers = curl_slist_append(headers, "Content-Type: application/json");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, alert_json.data());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, alert_json.size());
        
        // We do not wait for response handling in the hot path, strictly fire & forget (or minimal wait)
        CURLcode res = curl_easy_perform(curl);
        if(res != CURLE_OK) {
             std::cerr << "CURL failed: " << curl_easy_strerror(res) << "\n";
        }
        
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
    }
}
