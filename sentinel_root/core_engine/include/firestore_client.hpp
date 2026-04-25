#pragma once
#include <string_view>
#include <string>

class FirestoreClient {
public:
    FirestoreClient(std::string_view project_id);
    
    // Pushes json alert
    void push_alert(std::string_view alert_json);
    
private:
    std::string project_id_;
};
