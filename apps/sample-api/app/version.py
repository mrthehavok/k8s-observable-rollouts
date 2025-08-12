import os

from app.models.info import VersionInfo

version_info = VersionInfo(
    version="0.2.1",
    build_number=os.getenv("BUILD_NUMBER"),
    git_commit=os.getenv("GIT_COMMIT"),
    git_branch=os.getenv("GIT_BRANCH"),
)

changelog = {"0.1.0": "Initial version", "0.2.0": "Visible bump for rollout tests", "0.2.1": "Canary test bump"}
