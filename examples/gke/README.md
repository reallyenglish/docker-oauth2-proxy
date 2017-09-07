## Usage example on GKE

GCP has [Identity-Aware Proxy](https://cloud.google.com/iap/docs/) which provides same functionality.
But you may want identity-awareness your own way, or planning to use other identity providers later. Then you'll need this. Here I'll show you how to use it with GKE.

(See the [bitly/oauth2_proxy](https://github.com/bitly/oauth2_proxy) docs for configurations for different providers such as Github.)

### Step 0.(OPTIONAL) Setup cluster and network

Skip if you're installing it in an existing cluster.

```console
$ gcloud compute networks create "oauth-demo" --mode "custom"
$ gcloud compute networks subnets create "default" --network "oauth-demo" --range "10.170.0.0/20" --region "asia-northeast1"
$ gcloud compute firewall-rules create "default-allow-ssh" --network oauth-demo --allow tcp:22
$ gcloud compute firewall-rules create "default-allow-internal" --network "oauth-demo" --allow all --source-ranges "10.128.0.0/9"
$ gcloud container clusters create "oauth-demo" --cluster-version "1.7.4" --zone "asia-northeast1-a" --machine-type "n1-standard-4" --disk-size "200" --num-nodes "1" --network "oauth-demo" --subnetwork "default" --enable-cloud-logging --enable-cloud-monitoring
$ kubectl create namespace rproxy
```

### Step 1. Create Google Auth Provider

For Google, the registration steps are:

1. Create a new project if you haven't: https://console.developers.google.com/project
2. Choose the new project from the top right project dropdown (only if another project is selected)
3. In the project Dashboard center pane, choose **"Enable and manage APIs"**
4. In the left Nav pane, choose **"Credentials"**
5. In the center pane, choose **"OAuth consent screen"** tab. Fill in **"Product name shown to users"** and hit save.
6. In the center pane, choose **"Credentials"** tab.
   * Open the **"New credentials"** drop down
   * Choose **"OAuth client ID"**
   * Choose **"Web application"**
   * Application name is freeform, choose something appropriate
   * Authorized JavaScript origins is your domain ex: `https://internal.yourcompany.com`
   * Authorized redirect URIs is the location of oath2/callback ex: `https://internal.yourcompany.com/oauth2/callback`
   * Choose **"Create"**
4. Take note of the **Client ID** and **Client Secret**

It's recommended to refresh sessions on a short interval (1h) with `cookie-refresh` setting which validates that the account is still authorized.

### Step 2.(OPTIONAL) Restrict auth to specific Google groups on your domain

1. Create a [service account](https://developers.google.com/identity/protocols/OAuth2ServiceAccount) and make sure to download the json file.
2. Make note of the Client ID for a future step.
3. Under "APIs & Auth", choose APIs.
4. Click on Admin SDK and then Enable API.
5. Follow the steps on [Delegate domain-wide authority to your service account](https://developers.google.com/admin-sdk/directory/v1/guides/delegation#delegate_domain-wide_authority_to_your_service_account) and give the client id from step 2 the following oauth scopes:
```
https://www.googleapis.com/auth/admin.directory.group.readonly
https://www.googleapis.com/auth/admin.directory.user.readonly
```
6. Follow the steps on [Enable API access in the Admin console](https://support.google.com/a/answer/60757) to enable Admin API access.
7. Create or choose an existing administrative email address on the Gmail domain to assign to the ```google-admin-email``` flag. This email will be impersonated by this client to make calls to the Admin SDK. See the note on the link from step 5 for the reason why.
8. Create or choose an existing email group and set that email to the ```google-group``` flag. You can pass multiple instances of this flag with different groups
and the user will be checked against all the provided groups.
9. Lock down the permissions on the json file downloaded from __step 1__ so only `oauth2_proxy` is able to read the file and set the path to the file in the ```google-service-account-json``` flag.
10. Restart `oauth2_proxy`.(See next step)

Note: The user is checked against the group members list on initial authentication and every time the token is refreshed ( about once an hour ).

### Step 3. Deploy the oauth proxy to kubernetes

Create a secret for oauth client:
```console
$ kubectl create secret generic oauth --namespace=rproxy \
  --from-literal=OAUTH2_PROXY_COOKIE_SECRET='...' \
  --from-literal=OAUTH2_PROXY_CLIENT_ID='...' \
  --from-literal=OAUTH2_PROXY_CLIENT_SECRET='...'
```

Create a secret using your ssl certificates:
```console
$ kubectl create secret generic ssl-cert --namespace=rproxy \
  --from-file=cert.pem=/path/to/ssl/cert.pem \
  --from-file=key.pem=/path/to/ssl/key.pem \
  --from-file=trusted.pem=/path/to/ssl/trusted.pem \
  --from-file=dhparam.pem=/path/to/ssl/dhparam.pem
```


Reserve an static ip:
```console
gcloud compute addresses create ia-proxy --region asia-northeast1
# and use the created ip in `service.yaml:loadBalancerIP`.
```

Change `example.com` with proper domain in `*.yaml` files, then deploy:
```
$ kubectl apply -f . --namespace=rproxy
```
