# Update the config to use a cloud provider and region of your choice.
# https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/confluent_kafka_cluster
resource "confluent_kafka_cluster" "kafka_cluster" {
  display_name = var.cc_cluster_name
  availability = "SINGLE_ZONE"
  cloud        = var.cloud_provider
  region       = var.cloud_region
  basic {}
  environment {
    id = confluent_environment.cc_env.id
  }
}


# Stream Governance and Kafka clusters can be in different regions as well as different cloud providers,
# but you should to place both in the same cloud and region to restrict the fault isolation boundary.
data "confluent_schema_registry_region" "schema_registry" {
  cloud   = var.cloud_provider
  region  = var.cloud_region
  package = "ADVANCED"
}

resource "confluent_schema_registry_cluster" "schema_registry_cluster" {
  package = data.confluent_schema_registry_region.schema_registry.package

  environment {
    id = confluent_environment.cc_env.id
  }

  region {
    # See https://docs.confluent.io/cloud/current/stream-governance/packages.html#stream-governance-regions
    id = data.confluent_schema_registry_region.schema_registry.id
  }
}

// 'app-manager' service account is required in this configuration to create 'purchase' topic and grant ACLs
// to 'app-producer' and 'app-consumer' service accounts.
resource "confluent_service_account" "app-manager" {
  display_name = "${var.cc_env_display_name}-app-manager"
  description  = "Service account to manage Kafka cluster"
}

resource "confluent_role_binding" "app-manager-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.kafka_cluster.rbac_crn
}

resource "confluent_api_key" "app-manager-kafka-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.kafka_cluster.id
    api_version = confluent_kafka_cluster.kafka_cluster.api_version
    kind        = confluent_kafka_cluster.kafka_cluster.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  # The goal is to ensure that confluent_role_binding.app-manager-kafka-cluster-admin is created before
  # confluent_api_key.app-manager-kafka-api-key is used to create instances of
  # confluent_kafka_topic, confluent_kafka_acl resources.

  # 'depends_on' meta-argument is specified in confluent_api_key.app-manager-kafka-api-key to avoid having
  # multiple copies of this definition in the configuration which would happen if we specify it in
  # confluent_kafka_topic, confluent_kafka_acl resources instead.
  depends_on = [
    confluent_role_binding.app-manager-kafka-cluster-admin
  ]
}

resource "confluent_service_account" "env-manager" {
  display_name = "${var.cc_env_display_name}-env-manager"
  description  = "Service account to manage 'Staging' environment"
}

resource "confluent_role_binding" "env-manager-environment-admin" {
  principal   = "User:${confluent_service_account.env-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.cc_env.resource_name
}

resource "confluent_api_key" "env-manager-schema-registry-api-key" {
  display_name = "env-manager-schema-registry-api-key"
  description  = "Schema Registry API Key that is owned by 'env-manager' service account"
  owner {
    id          = confluent_service_account.env-manager.id
    api_version = confluent_service_account.env-manager.api_version
    kind        = confluent_service_account.env-manager.kind
  }

  managed_resource {
    id          = confluent_schema_registry_cluster.schema_registry_cluster.id
    api_version = confluent_schema_registry_cluster.schema_registry_cluster.api_version
    kind        = confluent_schema_registry_cluster.schema_registry_cluster.kind

    environment {
      id = confluent_environment.cc_env.id
    }
  }

  # The goal is to ensure that confluent_role_binding.env-manager-environment-admin is created before
  # confluent_api_key.env-manager-schema-registry-api-key is used to create instances of
  # confluent_schema resources.

  # 'depends_on' meta-argument is specified in confluent_api_key.env-manager-schema-registry-api-key to avoid having
  # multiple copies of this definition in the configuration which would happen if we specify it in
  # confluent_schema resources instead.
  depends_on = [
    confluent_role_binding.env-manager-environment-admin
  ]
}