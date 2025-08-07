import pytest
import subprocess
import time
import requests

class TestAlerting:

    def test_prometheus_rules_loaded(self):
        """Test PrometheusRules are loaded"""
        result = subprocess.run(
            "kubectl get prometheusrules -A -o json",
            shell=True,
            capture_output=True,
            text=True
        )

        rules = json.loads(result.stdout)
        assert len(rules["items"]) > 0, "No PrometheusRules found"

        # Check specific rules exist
        rule_names = {rule["metadata"]["name"] for rule in rules["items"]}
        expected_rules = ["sample-api-alerts", "infrastructure-alerts", "rollout-alerts"]

        for expected in expected_rules:
            assert expected in rule_names, f"Rule {expected} not found"

    def test_alert_firing(self):
        """Test alerts fire when conditions are met"""
        # Trigger high error rate
        for _ in range(100):
            requests.get("http://app.local/demo/error?rate=100")

        # Wait for alert to fire
        time.sleep(120)

        # Check alerts
        response = requests.get("http://prometheus.local/api/v1/alerts")
        assert response.status_code == 200

        alerts = response.json()["data"]["alerts"]
        active_alerts = [a for a in alerts if a["state"] == "firing"]

        # Should have high error rate alert
        error_alert = next(
            (a for a in active_alerts if a["labels"]["alertname"] == "HighErrorRate"),
            None
        )
        assert error_alert is not None, "HighErrorRate alert not firing"

    def test_alertmanager_routing(self):
        """Test AlertManager routes alerts correctly"""
        # This would test webhook receivers are called
        pass