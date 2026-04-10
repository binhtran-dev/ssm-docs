"""
Initialize Pub/Sub topics and subscriptions from the shared manifest.
Reads pubsub-manifest.yaml and creates all resources on the emulator.
"""

import os
import yaml
from google.cloud import pubsub_v1


def main():
    manifest_path = os.environ.get("PUBSUB_MANIFEST", "/app/pubsub-manifest.yaml")
    project_id = os.environ.get("GCP_PROJECT_ID", "ssm-local")

    with open(manifest_path) as f:
        manifest = yaml.safe_load(f)

    publisher = pubsub_v1.PublisherClient()
    subscriber = pubsub_v1.SubscriberClient()

    topics = manifest.get("topics", [])
    topic_count = 0
    sub_count = 0

    for topic_def in topics:
        topic_name = topic_def["name"]
        topic_path = publisher.topic_path(project_id, topic_name)

        try:
            publisher.create_topic(request={"name": topic_path})
            print(f"  Created topic: {topic_name}")
            topic_count += 1
        except Exception as e:
            if "AlreadyExists" in str(e):
                print(f"  Topic already exists: {topic_name}")
            else:
                print(f"  Error creating topic {topic_name}: {e}")
                continue

        for sub_def in topic_def.get("subscriptions", []):
            sub_name = sub_def["name"]
            sub_path = subscriber.subscription_path(project_id, sub_name)

            try:
                subscriber.create_subscription(
                    request={"name": sub_path, "topic": topic_path}
                )
                print(f"    Created subscription: {sub_name}")
                sub_count += 1
            except Exception as e:
                if "AlreadyExists" in str(e):
                    print(f"    Subscription already exists: {sub_name}")
                else:
                    print(f"    Error creating subscription {sub_name}: {e}")

    print(f"\nPub/Sub init complete: {topic_count} topics, {sub_count} subscriptions created.")


if __name__ == "__main__":
    main()
