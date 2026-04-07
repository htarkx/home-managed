#!/usr/bin/env bash
set -euo pipefail

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

cat >"$tmpfile" <<'PY'
import json
from secrets import token_urlsafe

from authentik.core.models import Application, Group, User
from authentik.crypto.models import CertificateKeyPair
from authentik.flows.models import Flow
from authentik.policies.models import PolicyBinding
from authentik.providers.oauth2.models import OAuth2Provider, ScopeMapping

authz_flow = Flow.objects.get(slug="default-provider-authorization-explicit-consent")
invalidation_flow = Flow.objects.get(slug="default-provider-invalidation-flow")
signing_key = CertificateKeyPair.objects.get(name="authentik Self-signed Certificate")

provider, created = OAuth2Provider.objects.get_or_create(
    name="grafana-oidc",
    defaults={
        "authorization_flow": authz_flow,
        "invalidation_flow": invalidation_flow,
        "client_type": "confidential",
        "client_id": token_urlsafe(30),
        "client_secret": token_urlsafe(48),
        "_redirect_uris": [
            {
                "url": "https://ob.home/login/generic_oauth",
                "matching_mode": "strict",
            }
        ],
        "include_claims_in_id_token": True,
        "issuer_mode": "per_provider",
        "sub_mode": "user_email",
        "signing_key": signing_key,
    },
)

provider.authorization_flow = authz_flow
provider.invalidation_flow = invalidation_flow
provider.client_type = "confidential"
provider._redirect_uris = [
    {
        "url": "https://ob.home/login/generic_oauth",
        "matching_mode": "strict",
    }
]
provider.include_claims_in_id_token = True
provider.issuer_mode = "per_provider"
provider.sub_mode = "user_email"
provider.signing_key = signing_key
provider.save()

provider.property_mappings.set(
    ScopeMapping.objects.filter(scope_name__in=["openid", "email", "profile"])
)

app, _ = Application.objects.update_or_create(
    slug="grafana",
    defaults={
        "name": "Grafana",
        "provider": provider,
        "meta_launch_url": "https://ob.home",
        "meta_description": "Grafana observability dashboard",
    },
)

grafana_group, _ = Group.objects.get_or_create(name="grafana-admins")
for user in list(User.objects.filter(groups=grafana_group)):
    if user.email.lower() != "htark666@gmail.com":
        user.groups.remove(grafana_group)

htark_user = User.objects.get(email__iexact="htark666@gmail.com")
htark_user.groups.add(grafana_group)

PolicyBinding.objects.update_or_create(
    target=app.policybindingmodel_ptr,
    group=grafana_group,
    defaults={
        "enabled": True,
        "order": 0,
        "timeout": 30,
        "failure_result": False,
        "negate": False,
    },
)

print("RESULT_JSON:" + json.dumps({
    "client_id": provider.client_id,
    "client_secret": provider.client_secret,
}))
PY

pod="$(kubectl get pod -n authentik -l app.kubernetes.io/component=server,app.kubernetes.io/name=authentik -o jsonpath='{.items[0].metadata.name}')"
kubectl cp "$tmpfile" "authentik/${pod}:/tmp/bootstrap-authentik-grafana-oauth.py"
output="$(
  kubectl exec -n authentik deploy/authentik-server -- bash -lc \
    'export AUTHENTIK_LOG_LEVEL=error; source /ak-root/.venv/bin/activate && python manage.py shell < /tmp/bootstrap-authentik-grafana-oauth.py && rm -f /tmp/bootstrap-authentik-grafana-oauth.py'
)"

result_json="$(printf '%s\n' "$output" | sed -n 's/^RESULT_JSON://p' | tail -1)"
if [ -z "$result_json" ]; then
  printf '%s\n' "$output" >&2
  echo "Could not parse Grafana OAuth client details from Authentik output." >&2
  exit 1
fi

client_id="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["client_id"])' <<<"$result_json")"
client_secret="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["client_secret"])' <<<"$result_json")"

kubectl -n monitoring create secret generic grafana-authentik-oauth \
  --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_ID="$client_id" \
  --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET="$client_secret" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Grafana Authentik OAuth provider and monitoring/grafana-authentik-oauth secret are configured."
