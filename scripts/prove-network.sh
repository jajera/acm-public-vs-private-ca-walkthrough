#!/usr/bin/env bash
# Stage 01: VPC, public/private subnets, IGW, NAT, routes, security groups.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/_prove_lib.sh
source "$ROOT/scripts/_prove_lib.sh"

cd "$ROOT/terraform/01-network"

prove_header "01" "Network"

AWS_REGION="$(terraform output -raw aws_region)"
VPC_ID="$(terraform output -raw vpc_id)"
IGW_ID="$(terraform output -raw internet_gateway_id)"
NAT_ID="$(terraform output -raw nat_gateway_id)"
mapfile -t PUBLIC_SUBNETS < <(terraform output -json public_subnet_ids | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)))')
mapfile -t PRIVATE_SUBNETS < <(terraform output -json private_subnet_ids | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)))')

CIDR="$(aws ec2 describe-vpcs --region "$AWS_REGION" --vpc-ids "$VPC_ID" \
  --query 'Vpcs[0].CidrBlock' --output text)"
prove_eq "VPC CIDR" "$CIDR" "10.42.0.0/16" || prove_die "unexpected VPC CIDR"
prove_info "vpc_id=$VPC_ID"

SUBNET_JSON="$(aws ec2 describe-subnets --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'sort_by(Subnets,&CidrBlock)[].{Cidr:CidrBlock,MapPublic:MapPublicIpOnLaunch}' \
  --output json)"

while IFS= read -r line; do
  [[ -n "$line" ]] && prove_ok "$line"
done < <(python3 - "$SUBNET_JSON" <<'PY'
import json, sys
subs = json.loads(sys.argv[1])
want = [
    ("10.42.0.0/24", True),
    ("10.42.1.0/24", True),
    ("10.42.10.0/24", False),
    ("10.42.11.0/24", False),
]
if len(subs) != 4:
    print(f"expected 4 subnets, got {len(subs)}", file=sys.stderr)
    sys.exit(1)
for sub, (cidr, pub) in zip(subs, want):
    if sub["Cidr"] != cidr or bool(sub["MapPublic"]) != pub:
        print(f"bad subnet {sub}, want {cidr} map_public={pub}", file=sys.stderr)
        sys.exit(1)
    tier = "public" if pub else "private"
    print(f"Subnet {cidr} ({tier})")
PY
) || prove_die "subnet layout mismatch"

[[ "${#PUBLIC_SUBNETS[@]}" -eq 2 && "${#PRIVATE_SUBNETS[@]}" -eq 2 ]] \
  || prove_die "expected 2 public + 2 private subnet outputs"
prove_ok "Terraform outputs list 2 public + 2 private subnets"

IGW_VPC="$(aws ec2 describe-internet-gateways --region "$AWS_REGION" \
  --internet-gateway-ids "$IGW_ID" \
  --query 'InternetGateways[0].Attachments[0].VpcId' --output text)"
prove_eq "IGW attached to lab VPC" "$IGW_VPC" "$VPC_ID" || prove_die "IGW not attached"

NAT_JSON="$(aws ec2 describe-nat-gateways --region "$AWS_REGION" \
  --nat-gateway-ids "$NAT_ID" \
  --query 'NatGateways[0].{State:State,Subnet:SubnetId}' --output json)"
NAT_STATUS="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["State"])' <<<"$NAT_JSON")"
NAT_SUBNET="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["Subnet"])' <<<"$NAT_JSON")"
prove_eq "NAT Gateway state" "$NAT_STATUS" "available" || prove_die "NAT not available"
[[ " ${PUBLIC_SUBNETS[*]} " == *" $NAT_SUBNET "* ]] || prove_die "NAT not in a public subnet"
prove_ok "NAT sits in a public subnet"

PUB_GW="$(aws ec2 describe-route-tables --region "$AWS_REGION" \
  --filters "Name=association.subnet-id,Values=${PUBLIC_SUBNETS[0]}" \
  --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId | [0]' \
  --output text)"
prove_eq "Public default route → IGW" "$PUB_GW" "$IGW_ID" || prove_die "public route wrong"

PRIV_NAT="$(aws ec2 describe-route-tables --region "$AWS_REGION" \
  --filters "Name=association.subnet-id,Values=${PRIVATE_SUBNETS[0]}" \
  --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId | [0]' \
  --output text)"
prove_eq "Private default route → NAT" "$PRIV_NAT" "$NAT_ID" || prove_die "private route wrong"

for label in alb internal-alb public-web private-web clients; do
  case "$label" in
    alb) out=alb_security_group_id ;;
    internal-alb) out=internal_alb_security_group_id ;;
    public-web) out=public_web_security_group_id ;;
    private-web) out=private_web_security_group_id ;;
    clients) out=clients_security_group_id ;;
  esac
  sg="$(terraform output -raw "$out")"
  aws ec2 describe-security-groups --region "$AWS_REGION" --group-ids "$sg" \
    --query 'SecurityGroups[0].GroupId' --output text >/dev/null
  prove_ok "Security group $label exists"
done

prove_pass "stage 01 network looks good — continue to stage 02"
