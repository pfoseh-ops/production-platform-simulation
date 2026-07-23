# Trade-offs

| Decision | Benefit | Cost or risk | Production evolution |
| --- | --- | --- | --- |
| EKS managed node group | Familiar Kubernetes operations and portable Helm deployment | Higher cost and operational surface than ECS/Fargate | Add Karpenter, separate system/workload pools, and scheduled upgrades |
| One NAT gateway | Keeps a short-lived simulation affordable | Cross-AZ dependency and data charges; not AZ-resilient | One NAT per AZ or VPC endpoints plus controlled egress |
| Two availability zones | Demonstrates zonal spreading with modest cost | Less fault isolation than three AZs | Use three AZs and validate zonal evacuation |
| Two worker nodes | Enough capacity for app and observability in a demo | Maintenance can constrain capacity | Minimum three nodes, diversified instance types, and autoscaling |
| Restricted public EKS API | GitHub-hosted runners can deploy without a self-hosted network path | Internet-routable endpoint remains, though CIDR restricted | Private endpoint plus self-hosted ephemeral runners |
| In-cluster Prometheus/Grafana | Fully reproducible and vendor-neutral | Cluster failure can impair monitoring | Remote-write to managed, cross-account observability |
| In-cluster alert webhook | Demonstrates the full alert path without third-party credentials | Same failure domain as the application | PagerDuty/Slack receiver with external secret management |
| Terraform-managed Grafana password | Simple repeatable install | Sensitive value exists in encrypted Terraform state | External Secrets Operator with Secrets Manager |
| Broad GitHub deployment role | Lets one isolated simulation stack create all required services | Excessive in a shared AWS account | Split bootstrap/network/platform roles, permissions boundary, SCP, and policy tests |
| Pinned tool/chart versions | Reproducible builds and plans | Versions require active maintenance | Dependabot/Renovate plus scheduled compatibility tests |
| Application S3 bucket protected from force deletion | Prevents accidental data loss | Teardown requires deliberate object/version cleanup | Add retention policy and a reviewed data-disposition workflow |

## Deliberate omissions

- No public ingress or DNS. Access is through `kubectl port-forward`, avoiding a
  public load balancer and TLS certificate cost. Add AWS Load Balancer
  Controller, Route 53, ACM, WAF, and an ingress policy for an internet service.
- No database. S3 satisfies the storage provisioning requirement while keeping
  the simulation understandable. Add RDS/Aurora with subnet groups, rotation,
  backups, and restore testing when relational state is required.
- No service mesh. mTLS and traffic shaping are valuable only when multiple
  services justify the operational overhead.
- No automatic destroy workflow. Destruction of stateful infrastructure is a
  deliberate operator action, not a normal CI event.

---

**Paul Foseh**<br>
Senior DevOps Engineer
