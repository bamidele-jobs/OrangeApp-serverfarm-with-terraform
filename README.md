# serverfarm-with-terraform-
**HOW DID I GET HERE**: Every outage has an origin story, and most of them start the same way: one server is made to do everything. Picture a growing web application like the **Serverfarm** The frontend, the business logic and the database all live on a single machine. It works beautifully until the day traffic spikes, a disk fills up, or an Availability Zone has a bad afternoon. Then the whole application goes dark at once, and the on-call engineer is left rebuilding a server from memory at 2 a.m. I wanted to know what it takes to make sure that story never gets written. So I set myself a brief: a brief to design a platform that survives the loss of a data centre, replaces its own broken servers, and keeps the database out of reach of the internet. No shortcuts, no default VPC, no clicking through wizards I didn't understand. I started by building the architecture by hand in the AWS console so I would genuinely understand every route, every subnet and every security group rule that will apply to this project. Each tier got its own network boundary. Security groups were chained so that each layer only trusts the layer above it. Auto Scaling Groups kept the fleet healthy, and an Application Load Balancer spread traffic across two Availability Zones. Then came the question every DevOps engineer eventually faces: "Great, now can you build it again, identically, in ten minutes?"A console build can't answer that. **Terraform can**. So I took the design and codified it: a custom VPC with a deliberate CIDR plan, public and private route tables, an Internet Gateway, a NAT Gateway with its own Elastic IP, a locked-down security group, a pinned network interface, and an encrypted, right-sized EC2 instance, all defined in code, version controlled, and destroyable with a single command. This repository is the result: an architecture I can explain, a codebase I can reproduce, and a bill I can switch off.

**Scope of the Project**
This project covers the full lifecycle of a highly available, three-tier AWS web application, delivered in three phases.
**Phase	Description	Status**
1. Design and manual build	Multi-AZ VPC, six subnets, IGW, NAT, three route tables, ALB, Auto Scaling Groups, RDS MySQL. Built in the console to learn the fundamentals. Documented in docs/.	Complete
2. Terraform foundation	Provider configuration, custom VPC, subnets, route tables, Internet Gateway, NAT Gateway, Elastic IPs, security group, ENI and an encrypted EC2 instance, in eu-west-2.	Complete
3. Terraform for the remaining tiers	ALB, target group, launch templates, Auto Scaling Groups, RDS and second-AZ subnets, restructured into modules with remote state.	In progress
**In scope:** network design, CIDR planning, tiered isolation, security group chaining, load balancing, auto healing, managed database, infrastructure as code, cost control and teardown.
**Out of scope (for now):** application code, CI/CD for the application itself, multi-region disaster recovery, container orchestration.

**Problem Statement**

A traditional single-server deployment creates four compounding risks:
**Risk and Impact**
_Single point of failure_: One instance or AZ failure takes down frontend, backend and data together
_No independent scaling_: A traffic spike on the web layer forces you to scale the database server too
_Large blast radius_:	A compromised web server has direct network access to the database
_Unreproducible infrastructure_:	Hand-built environments drift, and nobody can rebuild them reliably after an incident

**The challenge:** Design and deliver an architecture that removes these risks, and make it reproducible as code.

**Objectives**
Eliminate single points of failure by spreading every tier across two Availability Zones.
Isolate each tier into its own subnets with its own route table and security boundary.
Enforce least-privilege networking by chaining security groups so each tier only accepts traffic from the tier above.
Enable self-healing using Auto Scaling Groups with ELB health checks.
Keep the data tier private, with no public IP and no route from the internet.
Provide controlled outbound access for private instances through a NAT Gateway.
Make everything reproducible with Terraform: version controlled, reviewable, and destroyable.
Control cost with tagging, budgets and a documented teardown order.

**Traffic flows**
Flow												Path
Inbound web request	Client → Internet Gateway → ALB → Target Group → private app instance
Admin access	Admin → Internet Gateway → web tier (SSH) → app tier (SSH over private IP)
Outbound from private subnets	Instance → NAT Gateway → Internet Gateway → Internet
Database access	App instance → RDS endpoint on port 3306

**Network plan (Terraform build)**
Resource												Name															Value
VPC												serverfarm-vpc							50.0.0.0/16, DNS hostnames enabled
Public subnet							serverfarm-pubsn-2a						50.0.0.0/24, eu-west-2a
Private subnet						serverfarm-privsn-2a						50.0.1.0/24, eu-west-2a
Internet Gateway						serverfarm-igw								Attached to bello-vpc
Public route table				serverfarm_pubrt							0.0.0.0/0 → Internet Gateway
Private route table				serverfarm_privrt						0.0.0.0/0 → NAT Gateway
NAT Gateway								serverfarm-natgw					In the public subnet, with a dedicated Elastic IP
Network interface					serverfarm-eni						Fixed private IP 50.0.0.4, Elastic IP attached


**Tools and Components**
**Toolchain**
Tool																													Role in this project
Terraform																		Declares the entire infrastructure as code, with dependency-aware create and destroy
HashiCorp AWS Provider ~> 6.0								Translates Terraform resources into AWS API calls
AWS (eu-west-2, London)											Target cloud platform
AWS CLI / key pair (boot_keypair)						Authentication and SSH access
Git and GitHub															Version control and portfolio hosting
Bash user-data scripts											Bootstrap Apache and the MariaDB client on first boot (Amazon Linux 2023)
draw.io / Mermaid														Architecture diagrams


**AWS components and what each one does**
Layer																		AWS component															Purpose																								Terraform resource
**Network**																			VPC												Isolated private network for the whole project									aws_vpc
																Subnets (public / private)						Separate exposure levels per tier																		aws_subnet
																	Internet Gateway									Two-way internet path for public subnets										aws_internet_gateway
																Route tables and associations					Decide where each subnet's traffic goes								aws_route_table, aws_route_table_association
																	NAT Gateway + Elastic IP					Outbound-only internet for private instances									aws_nat_gateway, aws_eip
**Security**												Security group							Stateful firewall with explicit ingress and egress rules			aws_security_group, aws_vpc_security_group_ingress_rule,
																																																																		aws_vpc_security_group_egress_rule

**Compute**											Elastic Network Interface							Stable private IP and security group binding										aws_network_interface
																			Elastic IP														Stable public address																						aws_eip
																EC2 instance (t2.micro)								Application host with 12 GiB encrypted gp3 root volume							aws_instance
**Scale and availability**	Application Load Balancer,Target Group		Distribute traffic and detect unhealthy hosts						Documented in manual build, Terraform in progress
														Auto Scaling Groups (min 2 / desired 2 / max 3)		Self-healing and elasticity												Documented in manual build, Terraform in progress
**Data**										RDS MySQL + DB subnet group									Managed relational database spanning two AZs						Documented in manual build, Terraform in progress


**How It All Came Together**

The architecture is built from the bottom up. Each layer depends on the one beneath it, which is exactly how Terraform's dependency graph resolves it.

1. The foundation: VPC and CIDR plan. A dedicated /16 VPC with DNS hostnames enabled gives the project its own private address space. Carving it into /24 subnets leaves room for additional tiers and AZs without renumbering.

2. The doors: Internet Gateway and route tables. The public route table sends 0.0.0.0/0 to the Internet Gateway, which is what makes a subnet "public". The private route table sends it to the NAT Gateway instead, so private instances can fetch patches but can never be reached from outside.

3. The one-way valve: NAT Gateway. Placed in the public subnet with its own Elastic IP and an explicit depends_on on the Internet Gateway, so Terraform never tries to create it before its path to the internet exists.

4. The checkpoint: security groups. Rules are written as individual aws_vpc_security_group_*_rule resources instead of inline blocks, which makes each rule independently reviewable and diff-friendly. Management ports are pinned to a single /32 address.

5. The compute layer: ENI, EIP and EC2. The instance boots from a pre-created network interface with a fixed private IP, so its security group, address and Elastic IP are decoupled from the instance lifecycle. Its root volume is gp3 and encrypted at rest.

6. The resilience layer: ALB and Auto Scaling. Instances are spread across two AZs behind an Application Load Balancer. ELB health checks let the Auto Scaling Group replace instances that are running but not serving, and a sensible grace period stops it from killing instances that are still bootstrapping.

7. The vault: RDS in isolated subnets. The database sits in its own subnet group with no public access. Its security group accepts MySQL traffic from the application tier's security group and nothing else.

8. The safety net: tagging, teardown and cost control. Everything is named and tagged, .gitignore blocks state and secrets, and terraform destroy removes the stack in dependency order.

**Security Design**

Security groups are chained so each tier only accepts traffic from the tier above it.

Security group										Inbound												Source
ALB SG										HTTP 80 (HTTPS 443 planned)					0.0.0.0/0
Web tier SG								HTTP 80, SSH 22								ALB / trusted /32 only
App tier SG								HTTP 80, SSH 22								ALB SG, Web tier SG
Database SG								MySQL 3306										App tier SG only

**Good practices already in place**
1. Private and database subnets have no public IPs
2. Security groups reference other security groups rather than wide CIDR ranges
3. Management ports are restricted to a single /32 address
4. Root volumes are encrypted
5. RDS is not publicly accessible
6. State files, keys and *.tfvars are excluded from Git

**Challenges Faced**
1	Resource ordering. The private route table references the NAT Gateway, which needs an Elastic IP and an Internet Gateway that must already exist.
2	Provider v6 changes. Security group rules and network interface attachment moved to newer resource types and arguments, so older tutorials no longer applied.
3	Predictable networking. An instance needs a stable private IP and a stable public IP that survive replacement.
4	Private instances had no internet. Package installs through user data hang when the NAT path is wrong.
5	Health check flapping. Auto Scaling kept replacing instances that were still bootstrapping.
6	Least-privilege access. Admin access had to be possible without exposing SSH to the world.
7	Cost. NAT Gateways and load balancers bill hourly even when idle.
8	Secrets hygiene. Keys, state files and credentials must never reach GitHub.

**How It Was Solved**
1	Used resource references (aws_eip.bello-eip-2.id, aws_internet_gateway.bello-igw.id) so Terraform builds the dependency graph automatically, plus an explicit depends_on for the NAT Gateway.
2	Adopted aws_vpc_security_group_ingress_rule / egress_rule and primary_network_interface, verified against the provider 6.x documentation.
3	Created the ENI first with private_ips = ["50.0.0.4"], then bound an Elastic IP to that exact private address.
4	Verified the chain: private route table → NAT → public subnet → route table → IGW, and confirmed the NAT has an Elastic IP.
5	Increased the health check grace period (for example 300 seconds) to cover user-data execution time.
6	Pinned SSH to a single /32, used a jump-host pattern with agent forwarding (ssh -A) so private keys are never copied onto servers, and planned a move to Session Manager.
7	Tagged all resources, set an AWS Budget alert, documented the teardown order, and relied on terraform destroy for clean removal.
8	Added a .gitignore covering *.pem, *.tfstate*, *.tfvars, .env and .terraform/.

**Conclusion**

This project started with a simple question: what does it actually take to keep a web application online when things break?

The answer turned out to be a set of deliberate decisions rather than a single product: separate tiers so failures stay contained, two Availability Zones so a data centre is not a dependency, chained security groups so a breach in one layer does not become a breach in all of them, auto healing so recovery does not need a human, and Infrastructure as Code so the whole environment can be rebuilt, reviewed and destroyed on demand.

Building it by hand taught me why each component exists. Rebuilding it in Terraform taught me how to make it repeatable, auditable and safe to change. Together, they reflect how I approach DevOps: understand the system first, automate it second, and always know what it costs and how to turn it off.

Key takeaways

Highly available design is a network and security problem before it is a compute problem.
Dependency ordering and explicit relationships are what make Terraform builds reliable.
Least privilege, encryption and secret hygiene belong in the first commit, not the last.
Cost awareness is part of engineering, not an afterthought.

I used terraform to create multiple private and public servers in AWS.
Problem Statement 
Create a deployment of an EC2 instance using Terraform with Specific Parameters: T2.Micro 12GB Storage London Region Access to SSH and RDP from a single IP address Address to https from anywhere
Solution 
#1 Create VPC 
#2 Create IGW 
#3 Create a Public Route Table 
#4 Create a Public Subnet 
#5 Associate the Public Subnet with Public Route Table 
#6 Create Security Group 
#7 Create ENI within the public subnet 
#8 Assign an EIP to the ENI @ #7 
#9 Launch an EC2 instance.
