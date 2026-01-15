#!/usr/bin/env python3
"""
Deployment Orchestrator for Internal Developer Platform
Handles infrastructure provisioning, Kubernetes deployment, and rollback safety
"""

import subprocess
import sys
import time
import argparse
from typing import Dict, Optional, List


class DeploymentOrchestrator:
    """Orchestrates deployment with automatic rollback on failure"""
    
    def __init__(self, app_name: str, namespace: str = "default"):
        self.app_name = app_name
        self.namespace = namespace
        self.rollback_revision = None
    
    def deploy(self, manifest_path: str) -> bool:
        """Deploy application with automatic rollback on failure"""
        print(f"🚀 Starting deployment for {self.app_name}")
        
        # Store current revision for rollback
        self.rollback_revision = self._get_current_revision()
        print(f"📝 Current revision: {self.rollback_revision or 'None (first deployment)'}")
        
        # Apply Kubernetes manifest
        if not self._apply_manifest(manifest_path):
            print("❌ Failed to apply manifest")
            return False
        
        # Wait for rollout to complete
        print("⏳ Waiting for rollout to complete...")
        if not self._wait_for_rollout():
            print("❌ Rollout failed")
            self._perform_rollback()
            return False
        
        # Run health checks
        print("🏥 Running health checks...")
        if not self._run_health_checks():
            print("❌ Health checks failed")
            self._perform_rollback()
            return False
        
        print(f"✅ Deployment successful! {self.app_name} is healthy")
        return True
    
    def _get_current_revision(self) -> Optional[str]:
        """Get current deployment revision"""
        try:
            result = subprocess.run(
                ["kubectl", "rollout", "history", 
                 f"deployment/{self.app_name}", 
                 f"-n {self.namespace}"],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    # Get last revision number
                    return lines[-1].split()[0]
        except Exception as e:
            print(f"⚠️  Could not get current revision: {e}")
        return None
    
    def _apply_manifest(self, manifest_path: str) -> bool:
        """Apply Kubernetes manifest"""
        try:
            result = subprocess.run(
                ["kubectl", "apply", "-f", manifest_path, f"-n {self.namespace}"],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                print(f"✅ Manifest applied successfully")
                return True
            else:
                print(f"❌ Error applying manifest: {result.stderr}")
                return False
        except Exception as e:
            print(f"❌ Exception applying manifest: {e}")
            return False
    
    def _wait_for_rollout(self, timeout: int = 300) -> bool:
        """Wait for deployment rollout to complete"""
        try:
            result = subprocess.run(
                ["kubectl", "rollout", "status",
                 f"deployment/{self.app_name}",
                 f"-n {self.namespace}",
                 f"--timeout={timeout}s"],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            print(f"❌ Exception waiting for rollout: {e}")
            return False
    
    def _run_health_checks(self, timeout: int = 60) -> bool:
        """Validate deployment health"""
        checks = [
            self._check_pod_health(),
            self._check_service_endpoints(),
        ]
        return all(checks)
    
    def _check_pod_health(self) -> bool:
        """Check if pods are running and ready"""
        try:
            result = subprocess.run(
                ["kubectl", "get", "pods",
                 "-l", f"app={self.app_name}",
                 f"-n {self.namespace}",
                 "-o", "jsonpath={.items[*].status.phase}"],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                statuses = result.stdout.split()
                all_running = all(status == "Running" for status in statuses)
                if all_running:
                    print(f"✅ All {len(statuses)} pods are running")
                    return True
                else:
                    print(f"❌ Some pods are not running: {statuses}")
                    return False
        except Exception as e:
            print(f"❌ Error checking pod health: {e}")
        return False
    
    def _check_service_endpoints(self) -> bool:
        """Check if service has endpoints"""
        try:
            result = subprocess.run(
                ["kubectl", "get", "endpoints",
                 self.app_name,
                 f"-n {self.namespace}",
                 "-o", "jsonpath={.subsets[*].addresses[*].ip}"],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                endpoints = result.stdout.split()
                if endpoints:
                    print(f"✅ Service has {len(endpoints)} endpoints")
                    return True
                else:
                    print("❌ Service has no endpoints")
                    return False
        except Exception as e:
            print(f"❌ Error checking service endpoints: {e}")
        return False
    
    def _perform_rollback(self):
        """Automatic rollback to previous stable revision"""
        if not self.rollback_revision:
            print("⚠️  No previous revision to rollback to")
            return
        
        print(f"🔄 Deployment failed. Rolling back to revision {self.rollback_revision}")
        try:
            subprocess.run([
                "kubectl", "rollout", "undo",
                f"deployment/{self.app_name}",
                f"--to-revision={self.rollback_revision}",
                f"-n {self.namespace}"
            ])
            print("✅ Rollback initiated")
        except Exception as e:
            print(f"❌ Rollback failed: {e}")


def main():
    parser = argparse.ArgumentParser(description="Deploy application to Kubernetes")
    parser.add_argument("--app", required=True, help="Application name")
    parser.add_argument("--manifest", required=True, help="Path to Kubernetes manifest")
    parser.add_argument("--namespace", default="default", help="Kubernetes namespace")
    
    args = parser.parse_args()
    
    orchestrator = DeploymentOrchestrator(args.app, args.namespace)
    success = orchestrator.deploy(args.manifest)
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
