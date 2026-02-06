#!/bin/bash
echo "Правила:" && curl -s -u admin:admin http://localhost:3000/api/v1/provisioning/alert-rules | jq '.[].title'
echo -e "\nАктивные:" && curl -s -u admin:admin http://localhost:3000/api/alertmanager/grafana/api/v2/alerts | jq '.[].labels.alertname'
echo -e "\nПапки:" && curl -s -u admin:admin http://localhost:3000/api/folders | jq '.[].title'
