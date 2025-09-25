# Example Kafka-KEDA App based on Quarkus

## Kafka App based on Quarkus

Example app to read from a given Kafka topic and processing the message. Based on Quarkus. 

1. Create a Cluster with a local registry and Kafka (e.g. via [./hack/create-kind-cluster.sh](./hack/create-kind-cluster.sh))
2. Build and deploy the app to the local registry (localhost:5001):
   ```
   mvn package
   ```
3. Apply manifests (and optionally adjust before):
   ```
   kubectl apply -f target/kubernetes/kubernetes.yml
   ```
4. Test if messages get handled/logged: 
   1. Produce some Kafka messages in the topic
      ```
      kubectl -n kafka run kafka-producer --rm -ti --image=quay.io/strimzi/kafka:0.47.0-kafka-4.0.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic
      ```
   2. check the app logs
      ```
      kubectl logs -l app.kubernetes.io/name=quarkus-app
      ```

## Scale app with KEDA

You can scale the app with KEDA to distribute the message processing on multiple instances.

1. Apply the ScaledObject
   ```
   kubectl apply -f keda-scaler.yaml
   ```
2. Produce some load on the Kafka topic
   ```
   kubectl -n kafka run kafka-producer --rm -ti --image=quay.io/strimzi/kafka:0.47.0-kafka-4.0.0 --rm=true --restart=Never -- bin/kafka-producer-perf-test.sh --topic my-topic --num-records 100000 --record-size 10 --throughput -1 --producer-props bootstrap.servers=my-cluster-kafka-bootstrap:9092
   ```
3. Check how the quarkus-app gets upscaled by KEDA:
   ```
   kubectl get po -l app.kubernetes.io/name=quarkus-app -w
   ```