Access the Prometheus UI:

If you have cluster admin access, forward the port locally to interact with it:
```
kubectl port-forward -n nginx-ingress-kdistaging svc/prometheus-operated 9090:9090
```

To access these URLs

```
http://localhost:9090/query
http://localhost:9090/metrics
http://localhost:9090/targets
```
To start/stop/get status of prometheus service

```
sudo systemctl start prometheus
sudo systemctl stop prometheus
sudo systemctl status prometheus
```

To make node exporter run in background

```
### https://github.com/aussiearef/Prometheus/blob/main/node.service
[Unit]
Description=Prometheus Node Exporter
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/var/lib/node/node_exporter

SyslogIdentifier=prometheus_node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
```

We need create a user and group

```
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus
sudo mkir /var/lib/node/
## move the downloaded node_exporter to the path defined the service file above
sudo mv node_exporter /var/lib/node/

# create the above service in this path 
sudo nano /etc/systemd/system/node.service


sudo chown -R prometheus:prometheus /var/lib/node
sudo chown -R prometheus:prometheus /var/lib/node/*
sudo chmod -R 775 /var/lib/node
sudo chmod -R 775 /var/lib/node


sudo systemctl start prometheus
sudo systemctl enable prometheus
sudo systemctl status prometheus

```

Data types in PromQL
1. Scalar - It could be Float or String
2. Instant Vectors
3. Range Vectors

Prometheus Operators
1. Arithmatic
2. Binary (true or false)
3. Set Binary (and, or, unless)
4. Filter Matchers/Selectors
    '=' - two values must be equal
    '!=' - two values must not be equal
    '=~' - value on the left must match the regular expression on the right
    '!~' - value on the left must not match the regular expression on the right
5. Aggregation Operators
    'sum' - calculates sum over dimensions
    'min' - selects minimum over dimensions
    'max' - selects maximum over dimensions
    'avg' - selects average over dimensions
    'count' - selects number of elements over dimensions
    'group' - Groups elements.  All values in resulting vector are equal to 1
    'count_values' - Counts the number of elements with the same values
    'topk' - largest elements by sample value
    'bottomk' - smallest elements by sample value
    'stddev' - finds population standard deviation over dimensions
    'stdvar' - finds population standard variation over dimensions





1. 


To get the total memory consumed by a pod (specifically the memory working set, which is the actual memory in use), you can use Prometheus queries or Kubernetes commands. Since you’re already using Prometheus with your NGINX Ingress Controller pods in the nginx-ingress-kdistaging namespace, here’s how to do it:

```
container_memory_working_set_bytes{namespace="nginx-ingress-kdistaging", pod=~"nginx-ingress-kdistaging-nginx-ingress-controller.*"}
```

To see CPU usage rate over 5 minutes.
```
rate(container_cpu_usage_seconds_total{namespace="nginx-ingress-kdistaging", pod=~"nginx-ingress-kdistaging-nginx-ingress-controller.*"}[5m])
```

To see CPU usage rate over 1 hour.
```
rate(container_memory_working_set_bytes{namespace="nginx-ingress-kdistaging", pod=~"nginx-ingress-kdistaging-nginx-ingress-controller.*"}[1h])
```


