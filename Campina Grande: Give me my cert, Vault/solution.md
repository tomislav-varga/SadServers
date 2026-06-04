# Solution for Campina Grande: Give me my cert, Vault
## Description
A web application running at https://nginx.example.com has an expired certificate. Issue a new certificate using the Hashicorp Vault running on the server.
The Vault instance is already unsealed and initialized, and you have full admin access with the admin user.
The certificate presented by Nginx is issued by the Vault PKI (check using openssl verify -CAfile /usr/local/share/ca-certificates/vault-pki-ca.crt /etc/nginx/ssl/cert.pem).
**Test**: Running curl https://nginx.example.com returns Hello!. 
## Problem Analysis
```bash
curl -v https://nginx.example.com
* Host nginx.example.com:443 was resolved.
* IPv6: (none)
* IPv4: 127.0.0.1
*   Trying 127.0.0.1:443...
* ALPN: curl offers h2,http/1.1
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
*  CAfile: /etc/ssl/certs/ca-certificates.crt
*  CApath: /etc/ssl/certs
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (OUT), TLS alert, unknown CA (560):
* SSL certificate problem: self-signed certificate
* closing connection #0
curl: (60) SSL certificate problem: self-signed certificate
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the webpage mentioned above.
```
The error message indicates that the certificate presented by the server is not trusted by the client (curl). This is likely because the certificate is either self-signed or issued by a CA that is not included in the client's trusted CA store.
To resolve this issue, we need to ensure that the certificate presented by Nginx is issued by a trusted CA, which in this case is the Vault PKI. We will need to issue a new certificate for Nginx using Vault and configure Nginx to use this new certificate.
## Solution
1. Log in to the Vault server and issue a new certificate for Nginx using the Vault PKI. You can use the following command to issue a new certificate:
```bash
vault write pki/issue/nginx common_name=nginx.example.com ttl=24h
```
# Terminal Output
```bash
admin@i-0d9740ae82212691c:~$ curl -v https://nginx.example.com
* Host nginx.example.com:443 was resolved.
* IPv6: (none)
* IPv4: 127.0.0.1
*   Trying 127.0.0.1:443...
* ALPN: curl offers h2,http/1.1
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
*  CAfile: /etc/ssl/certs/ca-certificates.crt
*  CApath: /etc/ssl/certs
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (OUT), TLS alert, unknown CA (560):
* SSL certificate problem: self-signed certificate
* closing connection #0
curl: (60) SSL certificate problem: self-signed certificate
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the webpage mentioned above.
admin@i-0d9740ae82212691c:~$ vault write pki/issue/nginx common_name=nginx.example.com ttl=24h
WARNING! VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200.
Error writing data to pki/issue/nginx: Error making API request.

URL: PUT https://127.0.0.1:8200/v1/pki/issue/nginx
Code: 400. Errors:

* unknown role: nginx
admin@i-0d9740ae82212691c:~$ vault status
vault secrets list
vault list pki/roles
WARNING! VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200.
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.20.3
Build Date      2025-08-27T10:53:27Z
Storage Type    file
Cluster Name    vault-cluster-6a11b93f
Cluster ID      7be06b71-a952-870d-5ed0-ca946beb9d82
HA Enabled      false
WARNING! VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200.
Path                 Type         Accessor              Description
----                 ----         --------              -----------
cubbyhole/           cubbyhole    cubbyhole_21563690    per-token private secret storage
identity/            identity     identity_d151eff8     identity store
pki-intermediate/    pki          pki_8d060883          n/a
pki/                 pki          pki_48bbc190          n/a
sys/                 system       system_698a3944       system endpoints used for control, policy and debugging
WARNING! VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200.
Keys
----
cert-admin
admin@i-0d9740ae82212691c:~$ openssl verify -CAfile /usr/local/share/ca-certificates/vault-pki-ca.crt /etc/nginx/ssl/cert.pem
CN=demo.local
error 18 at 0 depth lookup: self-signed certificate
CN=demo.local
error 10 at 0 depth lookup: certificate has expired
error /etc/nginx/ssl/cert.pem: verification failed
admin@i-0d9740ae82212691c:~$ vault list pki-intermediate/roles
WARNING! VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200.
Keys
----
cert-admin
admin@i-0d9740ae82212691c:~$ vault write pki-intermediate/roles/nginx \
    allowed_domains="example.com" \
    allow_subdomains=true \
    allow_bare_domains=false \
    max_ttl="72h"
WARNING! VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200.
Key                                   Value
---                                   -----
allow_any_name                        false
allow_bare_domains                    false
allow_glob_domains                    false
allow_ip_sans                         true
allow_localhost                       true
allow_subdomains                      true
allow_token_displayname               false
allow_wildcard_certificates           true
allowed_domains                       [example.com]
allowed_domains_template              false
allowed_other_sans                    []
allowed_serial_numbers                []
allowed_uri_sans                      []
allowed_uri_sans_template             false
allowed_user_ids                      []
basic_constraints_valid_for_non_ca    false
client_flag                           true
cn_validations                        [email hostname]
code_signing_flag                     false
country                               []
email_protection_flag                 false
enforce_hostnames                     true
ext_key_usage                         []
ext_key_usage_oids                    []
generate_lease                        false
issuer_ref                            default
key_bits                              2048
key_type                              rsa
key_usage                             [DigitalSignature KeyAgreement KeyEncipherment]
locality                              []
max_ttl                               72h
no_store                              false
not_after                             n/a
not_before_duration                   30s
organization                          []
ou                                    []
policy_identifiers                    []
postal_code                           []
province                              []
require_cn                            true
serial_number_source                  json-csr
server_flag                           true
signature_bits                        256
street_address                        []
ttl                                   0s
use_csr_common_name                   true
use_csr_sans                          true
use_pss                               false
admin@i-0d9740ae82212691c:~$ vault write pki-intermediate/issue/nginx \
    common_name="nginx.example.com" \
    ttl="24h"
WARNING! VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200.
Key                 Value
---                 -----
ca_chain            [-----BEGIN CERTIFICATE-----
MIIDnzCCAoegAwIBAgIUd0ZhAmsb9n7PLHh1vz/zn0/FdGQwDQYJKoZIhvcNAQEL
BQAwFjEUMBIGA1UEAxMLZXhhbXBsZS5jb20wHhcNMjUwOTEwMTg0NTAxWhcNMjYw
OTEwMTg0NDUxWjAmMSQwIgYDVQQDExtleGFtcGxlLmNvbSBJbnRlcm1lZGlhdGUg
Q0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDO7wSMHskO3S+vU/H/
tJbd3h97FKaiuy89MSUt/HUKGa/tmfl7GHPvrxwt6aLIJxumg2oFoTJ5F0R7XX7r
MBffGmTpIC9lrC98Zh1NkDOLYce0qlh6mVbUV7eX/jdiniPD9GB8n8aqMvokL4fA
s12PE8PZNRKxvwrjn9m6CbfCcnsFFUe1N04auERvtUO5VCFYow0VJLkt+KMLGW+P
kF+nRbyUoCyTo43kEIF+k5S9BfZvp7hivnfyeYMqx+kIJE1UY7ORXOoqT/XhHs9M
ZfOOlUFmC3isLwSoxCXSjP4+XsR1/yOgCezo13I1wmfSCNw9rKC44UZkfJQCbIAL
WZobAgMBAAGjgdQwgdEwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8w
HQYDVR0OBBYEFEOPQHRkBKhAltshaeJAETIAXR9fMB8GA1UdIwQYMBaAFJEHcrjY
iBFkD4ZRZIEl1uFqyE0wMDsGCCsGAQUFBwEBBC8wLTArBggrBgEFBQcwAoYfaHR0
cDovLzEyNy4wLjAuMTo4MjAwL3YxL3BraS9jYTAxBgNVHR8EKjAoMCagJKAihiBo
dHRwOi8vMTI3LjAuMC4xOjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOC
AQEAcLKBm6m/w8jkWrBerQlVw/UPyyBrdEx0dtVMUL7chMVxCZntpF7tyRdV2cSz
K2oy4HHRrM9Cp9B47Mwq8TA4gnKfq+c1KIy3kJyyOQQshQs1JFBdzBOU0NGxrmxZ
0fBwP3DL3kT/2dx0fl7G59sjdlka0YHbLAAV6g5KOgTTj+/FUbWm7AnJs1ymPqHJ
jrKO2V8uvN2TD64w3d1N6mwF7lohw1U8mUZOhjylF5vdFtSOTJ0D+ByhgrGt2qbZ
POZiWBoV8gLDSsSgrR4tfjQt0iblSzIPj1c0nZO1Lh6ujCUASJkz16sAiK8YsZoc
2OjJ9YuqYpzkoVZ39CPpV4xaig==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDNTCCAh2gAwIBAgIUHaYIBEguLT/GkP/E1f8mYY02LzwwDQYJKoZIhvcNAQEL
BQAwFjEUMBIGA1UEAxMLZXhhbXBsZS5jb20wHhcNMjUwOTEwMTg0NDI2WhcNMjYw
OTEwMTg0NDUxWjAWMRQwEgYDVQQDEwtleGFtcGxlLmNvbTCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAKttjfyVCV1CYXqVrPCp1+8nX/8qKq/qcotS+K3G
8rQyIKhOnr1AGVm5NuJZoFEuvAJxpxVmiL/jk9wHme80O2687y42NwarzMwOWrDG
/bzzzLEmQ24lrr0mHjdkYHMluG0jpLy5Q2dZ0PCOs8ldkWNRep6FffS5cl1Mt4QY
FWZKif/Ca68WP94A4keDD7+JGY+w+NxB4qHDG2PC/rMCcoWQ4QsJNH9h7256rLyr
r7i8Ez4DiE46VDvIF1aj1bUFDjQGTgO8qKUjqe7TqpV2Ubw9naPjm7VcGX45G/zI
Wdn/AZMsixEoPme/5trd1JXTFdc7N5t7ChwJrzNEnFcZJwECAwEAAaN7MHkwDgYD
VR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFJEHcrjYiBFk
D4ZRZIEl1uFqyE0wMB8GA1UdIwQYMBaAFJEHcrjYiBFkD4ZRZIEl1uFqyE0wMBYG
A1UdEQQPMA2CC2V4YW1wbGUuY29tMA0GCSqGSIb3DQEBCwUAA4IBAQAGehO96QkD
u+fcEOwwsbAzRDV6YM01iJSgVyW//K4Bm4/m7OjBsO+swUHrl/DcagvmHqd+2YmZ
dayn9REhjyl7wc0VRTt/CMCkC2ZJ4MvOHYex3hm2voj09lzeCrbPGdxgnWRKAK+X
iRqsNrBbAcn+hU6ePjS+o+MZPWPeGAGh46lOBaUhZ+iASnHu+M9AK3Dl5yFCUyBu
Fe+sxQAoY+h/j3OGu8FH1gD802krMhN93PVVvF5Vr/eRYQwKLCA2BQvc+eQoau4o
HxEVNwENpZSMYU8zZh5wAx5LjI9Ip2QWzuoLWlGddoJnHJoJj/46rKQRpLJLkf1I
dAb0pmtctEIh
-----END CERTIFICATE-----]
certificate         -----BEGIN CERTIFICATE-----
MIIDYTCCAkmgAwIBAgIUOOYfzFsAVcsjay1sHiKNxx1X/hAwDQYJKoZIhvcNAQEL
BQAwJjEkMCIGA1UEAxMbZXhhbXBsZS5jb20gSW50ZXJtZWRpYXRlIENBMB4XDTI2
MDIxNzAzMTk0NloXDTI2MDIxODAzMjAxNVowHDEaMBgGA1UEAxMRbmdpbnguZXhh
bXBsZS5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCl/rwETknR
0r8SGebiO8CVDZm8hUf3KWvalvqvUsSH6S1zckdaju8rJ690bgnFls/2BFsD6dJT
xARPb9VnjOZWVzC9rWMbx1I7ZfGM847fml6BD4JMXoSX26mFAujSYShWBZuUtTg3
oO0fTv/8C0bBoznIxGnl1NKVs/fKFaBNMqhfJTO4/+DajFqdLUHAgP6exgJkPs/M
shIS4dQ83AbbqdS2FC1gEgcO6AMIMN21qgWECr68fbsDThviqhRQB45D55fvbGJ0
l1QE83NM2//+f25H4ejOuCBjqNlEM+Q89aMwQynM7nhn1JxJptl5ccx+sqEsGqTk
2bBePXXYcpPDAgMBAAGjgZAwgY0wDgYDVR0PAQH/BAQDAgOoMB0GA1UdJQQWMBQG
CCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUulR68O0Uy0+DZanjEGj/t6GA
PhEwHwYDVR0jBBgwFoAUQ49AdGQEqECW2yFp4kARMgBdH18wHAYDVR0RBBUwE4IR
bmdpbnguZXhhbXBsZS5jb20wDQYJKoZIhvcNAQELBQADggEBAItR/QnbttwXYx5Z
2XnD3X5QPloUCJgGmwLI0NBg4WBkucMyBp4ROoP1BKBFLad4BkKyzVXb7ur5RbMC
PR97NMhAorYWui1Zr71NKGRqmRjseAuv/5T2fResqOzHz5Ub7i04Fvg/b2mD2fm+
zrfWO14UY7AIu7pMJiR7ELLs01FHHifHmkMd/OKNUQs/rifZ47mD8EG6ZlX7ZJko
JtKvpjon5OOWmuHXpnNw/0iSq+AEumbFbiaDdTtOXFYBMuAiIrhGhsKcbGyLAfTB
MyDioWPy56w+QkL3X2OytVEadcoczEZyQzoKFOtzXp14ItP0QkJjUzXC8tzTeCAg
nLcuOhA=
-----END CERTIFICATE-----
expiration          1771384815
issuing_ca          -----BEGIN CERTIFICATE-----
MIIDnzCCAoegAwIBAgIUd0ZhAmsb9n7PLHh1vz/zn0/FdGQwDQYJKoZIhvcNAQEL
BQAwFjEUMBIGA1UEAxMLZXhhbXBsZS5jb20wHhcNMjUwOTEwMTg0NTAxWhcNMjYw
OTEwMTg0NDUxWjAmMSQwIgYDVQQDExtleGFtcGxlLmNvbSBJbnRlcm1lZGlhdGUg
Q0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDO7wSMHskO3S+vU/H/
tJbd3h97FKaiuy89MSUt/HUKGa/tmfl7GHPvrxwt6aLIJxumg2oFoTJ5F0R7XX7r
MBffGmTpIC9lrC98Zh1NkDOLYce0qlh6mVbUV7eX/jdiniPD9GB8n8aqMvokL4fA
s12PE8PZNRKxvwrjn9m6CbfCcnsFFUe1N04auERvtUO5VCFYow0VJLkt+KMLGW+P
kF+nRbyUoCyTo43kEIF+k5S9BfZvp7hivnfyeYMqx+kIJE1UY7ORXOoqT/XhHs9M
ZfOOlUFmC3isLwSoxCXSjP4+XsR1/yOgCezo13I1wmfSCNw9rKC44UZkfJQCbIAL
WZobAgMBAAGjgdQwgdEwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8w
HQYDVR0OBBYEFEOPQHRkBKhAltshaeJAETIAXR9fMB8GA1UdIwQYMBaAFJEHcrjY
iBFkD4ZRZIEl1uFqyE0wMDsGCCsGAQUFBwEBBC8wLTArBggrBgEFBQcwAoYfaHR0
cDovLzEyNy4wLjAuMTo4MjAwL3YxL3BraS9jYTAxBgNVHR8EKjAoMCagJKAihiBo
dHRwOi8vMTI3LjAuMC4xOjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOC
AQEAcLKBm6m/w8jkWrBerQlVw/UPyyBrdEx0dtVMUL7chMVxCZntpF7tyRdV2cSz
K2oy4HHRrM9Cp9B47Mwq8TA4gnKfq+c1KIy3kJyyOQQshQs1JFBdzBOU0NGxrmxZ
0fBwP3DL3kT/2dx0fl7G59sjdlka0YHbLAAV6g5KOgTTj+/FUbWm7AnJs1ymPqHJ
jrKO2V8uvN2TD64w3d1N6mwF7lohw1U8mUZOhjylF5vdFtSOTJ0D+ByhgrGt2qbZ
POZiWBoV8gLDSsSgrR4tfjQt0iblSzIPj1c0nZO1Lh6ujCUASJkz16sAiK8YsZoc
2OjJ9YuqYpzkoVZ39CPpV4xaig==
-----END CERTIFICATE-----
private_key         -----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEApf68BE5J0dK/Ehnm4jvAlQ2ZvIVH9ylr2pb6r1LEh+ktc3JH
Wo7vKyevdG4JxZbP9gRbA+nSU8QET2/VZ4zmVlcwva1jG8dSO2XxjPOO35pegQ+C
TF6El9uphQLo0mEoVgWblLU4N6DtH07//AtGwaM5yMRp5dTSlbP3yhWgTTKoXyUz
uP/g2oxanS1BwID+nsYCZD7PzLISEuHUPNwG26nUthQtYBIHDugDCDDdtaoFhAq+
vH27A04b4qoUUAeOQ+eX72xidJdUBPNzTNv//n9uR+HozrggY6jZRDPkPPWjMEMp
zO54Z9ScSabZeXHMfrKhLBqk5NmwXj112HKTwwIDAQABAoIBABPiVE5lvGUEjDvU
W3ptMvAH7YsOIiVC0ncgT84xqXYoYffq0A5SgebW/acCSWxgWO/87JQm7bl4CRYk
7NjXIX5lOmL2QqGAumKAHzPFty8k1D48h9yzE8oHF6LlytLsrYLEcDMblCzhu5Xd
BkAAb8zhSxo4IQFVgZZKNRwBhC7K+ax8JPFpaRFGaanWGWk7Kb5Nfx3R7wKEjfLk
LIP38HDIKdGWC2qndR8aPMr2Qfa0MHC9dvoxAZF0j1tULFGBIYoxusCdLnvf3nJ2
76rphyyR6qpbQFwrfu9qfqLbkxFOf3xrtxxgexLBudd12H1nUcMgI9zC4c1QQb8i
OPmpm20CgYEAwH3AOHWpRRnTTe6WpSXbOzMLE0y0us+wyNHM4cugJXfGcaFBhV7m
tPLTj/1feXuXC4Gosxps82Ck0DUJVvIs62gAjj6fdzI1345gkZ72j/b+Yh1l8Tt+
6VxVHkdHHAb6AbIiKen7c1rb3H0sxB/TbUL0dAdv5bbIyALaVw3khJcCgYEA3MMO
rt+sKOmuTodNP7SaJ76l503lyP5jihEw4Uj+0oNaV8H7sfGmuNPKGnf56T3mlyws
zbPnRqJIOT3CqjxEnYAdVY+8mEQ+hREY3oVnwhqcOELg97VFu8jI2GgOY3OlKFGg
d/ezwlcl9XvoxxAn6bosM2hOo7dqNNy3jwlXc7UCgYBHcKRdj/WhqsMMomcQpesm
nnwWzpoo1xoyfgL/LjaikUB6PbH2kNEpCRJR12SOzrqxT47P4hfbf9vLVlPADCN1
vuSt5joC4AS0kr/ua8PwjGe+/FAwZrdkXptMoIGYulIhPP6G9csX9fmxbFen9nPe
kkHtqjDyXZNJAB4Ovx43wwKBgBpaElOfkX5kvpDTJ8518XzTDhy5OLewXhNqD+qk
ev6H/W3CUxgfn2YqqdJVBfjokbDz7fk0A2R0FKj4jVci0JH4bAf9m2aVptzdeJl/
VS5fXMx+dzo6YjOTOR5T9Xu7nzhb3grT/5owKvDNtLCmZg1JUuNkDRcP2taqjiK9
27mNAoGBAK536674BfMREhGBOFGVpb4yoOnwjrn3bEx0gIim6XsaSPwWalreShF5
ibjlnmGFHNq47369ifSoOH+CLfFYuxa/4ZdnQNuXb9N6Z8/+/O6XDwkE6otp1Tt3
hZXZm3iJdTuTC+UC1xsbdNc0JVuzk+n5N3gI3n3NzPzKqBTj6b0D
-----END RSA PRIVATE KEY-----
private_key_type    rsa
serial_number       38:e6:1f:cc:5b:00:55:cb:23:6b:2d:6c:1e:22:8d:c7:1d:57:fe:10
admin@i-0d9740ae82212691c:~$ vault list pki-intermediate/roles
WARNING! VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200.
Keys
----
cert-admin
nginx
admin@i-0d9740ae82212691c:~$ openssl verify -CAfile /usr/local/share/ca-certificates/vault-pki-ca.crt /etc/nginx/ssl/cert.pem
CN=demo.local
error 18 at 0 depth lookup: self-signed certificate
CN=demo.local
error 10 at 0 depth lookup: certificate has expired
error /etc/nginx/ssl/cert.pem: verification failed
admin@i-0d9740ae82212691c:~$ !1
curl -v https://nginx.example.com
* Host nginx.example.com:443 was resolved.
* IPv6: (none)
* IPv4: 127.0.0.1
*   Trying 127.0.0.1:443...
* ALPN: curl offers h2,http/1.1
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
*  CAfile: /etc/ssl/certs/ca-certificates.crt
*  CApath: /etc/ssl/certs
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (OUT), TLS alert, unknown CA (560):
* SSL certificate problem: self-signed certificate
* closing connection #0
curl: (60) SSL certificate problem: self-signed certificate
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the webpage mentioned above.
admin@i-0d9740ae82212691c:~$ openssl x509 -in /etc/nginx/ssl/cert.pem -noout -issuer -subject -dates
issuer=CN=demo.local
subject=CN=demo.local
notBefore=Sep  7 18:43:45 2025 GMT
notAfter=Sep  8 18:43:45 2025 GMT
admin@i-0d9740ae82212691c:~$ grep ssl_certificate -R /etc/nginx
/etc/nginx/sites-enabled/default:    ssl_certificate     /etc/nginx/ssl/cert.pem;
/etc/nginx/sites-enabled/default:    ssl_certificate_key /etc/nginx/ssl/key.pem;
/etc/nginx/snippets/snakeoil.conf:ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
/etc/nginx/snippets/snakeoil.conf:ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
/etc/nginx/sites-available/default:    ssl_certificate     /etc/nginx/ssl/cert.pem;
/etc/nginx/sites-available/default:    ssl_certificate_key /etc/nginx/ssl/key.pem;
admin@i-0d9740ae82212691c:~$ jq
jq - commandline JSON processor [version 1.7]

Usage:  jq [options] <jq filter> [file...]
        jq [options] --args <jq filter> [strings...]
        jq [options] --jsonargs <jq filter> [JSON_TEXTS...]

jq is a tool for processing JSON inputs, applying the given filter to
its JSON text inputs and producing the filter's results as JSON on
standard output.

The simplest filter is ., which copies jq's input to its output
unmodified except for formatting. For more advanced filters see
the jq(1) manpage ("man jq") and/or https://jqlang.github.io/jq/.

Example:

        $ echo '{"foo": 0}' | jq .
        {
          "foo": 0
        }

For listing the command options, use jq --help.
admin@i-0d9740ae82212691c:~$ vault write -format=json pki-intermediate/issue/nginx \
  common_name="demo.local" \
  ttl="24h" > cert.json
WARNING! VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200.
Error writing data to pki-intermediate/issue/nginx: Error making API request.

URL: PUT https://127.0.0.1:8200/v1/pki-intermediate/issue/nginx
Code: 400. Errors:

* common name demo.local not allowed by this role
admin@i-0d9740ae82212691c:~$ vault write -format=json pki-intermediate/issue/nginx   common_name="nginx.example.com"   ttl="24h" > cert.json
WARNING! VAULT_ADDR and -address unset. Defaulting to https://127.0.0.1:8200.
admin@i-0d9740ae82212691c:~$ jq .data cert.json
{
  "ca_chain": [
    "-----BEGIN CERTIFICATE-----\nMIIDnzCCAoegAwIBAgIUd0ZhAmsb9n7PLHh1vz/zn0/FdGQwDQYJKoZIhvcNAQEL\nBQAwFjEUMBIGA1UEAxMLZXhhbXBsZS5jb20wHhcNMjUwOTEwMTg0NTAxWhcNMjYw\nOTEwMTg0NDUxWjAmMSQwIgYDVQQDExtleGFtcGxlLmNvbSBJbnRlcm1lZGlhdGUg\nQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDO7wSMHskO3S+vU/H/\ntJbd3h97FKaiuy89MSUt/HUKGa/tmfl7GHPvrxwt6aLIJxumg2oFoTJ5F0R7XX7r\nMBffGmTpIC9lrC98Zh1NkDOLYce0qlh6mVbUV7eX/jdiniPD9GB8n8aqMvokL4fA\ns12PE8PZNRKxvwrjn9m6CbfCcnsFFUe1N04auERvtUO5VCFYow0VJLkt+KMLGW+P\nkF+nRbyUoCyTo43kEIF+k5S9BfZvp7hivnfyeYMqx+kIJE1UY7ORXOoqT/XhHs9M\nZfOOlUFmC3isLwSoxCXSjP4+XsR1/yOgCezo13I1wmfSCNw9rKC44UZkfJQCbIAL\nWZobAgMBAAGjgdQwgdEwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8w\nHQYDVR0OBBYEFEOPQHRkBKhAltshaeJAETIAXR9fMB8GA1UdIwQYMBaAFJEHcrjY\niBFkD4ZRZIEl1uFqyE0wMDsGCCsGAQUFBwEBBC8wLTArBggrBgEFBQcwAoYfaHR0\ncDovLzEyNy4wLjAuMTo4MjAwL3YxL3BraS9jYTAxBgNVHR8EKjAoMCagJKAihiBo\ndHRwOi8vMTI3LjAuMC4xOjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOC\nAQEAcLKBm6m/w8jkWrBerQlVw/UPyyBrdEx0dtVMUL7chMVxCZntpF7tyRdV2cSz\nK2oy4HHRrM9Cp9B47Mwq8TA4gnKfq+c1KIy3kJyyOQQshQs1JFBdzBOU0NGxrmxZ\n0fBwP3DL3kT/2dx0fl7G59sjdlka0YHbLAAV6g5KOgTTj+/FUbWm7AnJs1ymPqHJ\njrKO2V8uvN2TD64w3d1N6mwF7lohw1U8mUZOhjylF5vdFtSOTJ0D+ByhgrGt2qbZ\nPOZiWBoV8gLDSsSgrR4tfjQt0iblSzIPj1c0nZO1Lh6ujCUASJkz16sAiK8YsZoc\n2OjJ9YuqYpzkoVZ39CPpV4xaig==\n-----END CERTIFICATE-----",
    "-----BEGIN CERTIFICATE-----\nMIIDNTCCAh2gAwIBAgIUHaYIBEguLT/GkP/E1f8mYY02LzwwDQYJKoZIhvcNAQEL\nBQAwFjEUMBIGA1UEAxMLZXhhbXBsZS5jb20wHhcNMjUwOTEwMTg0NDI2WhcNMjYw\nOTEwMTg0NDUxWjAWMRQwEgYDVQQDEwtleGFtcGxlLmNvbTCCASIwDQYJKoZIhvcN\nAQEBBQADggEPADCCAQoCggEBAKttjfyVCV1CYXqVrPCp1+8nX/8qKq/qcotS+K3G\n8rQyIKhOnr1AGVm5NuJZoFEuvAJxpxVmiL/jk9wHme80O2687y42NwarzMwOWrDG\n/bzzzLEmQ24lrr0mHjdkYHMluG0jpLy5Q2dZ0PCOs8ldkWNRep6FffS5cl1Mt4QY\nFWZKif/Ca68WP94A4keDD7+JGY+w+NxB4qHDG2PC/rMCcoWQ4QsJNH9h7256rLyr\nr7i8Ez4DiE46VDvIF1aj1bUFDjQGTgO8qKUjqe7TqpV2Ubw9naPjm7VcGX45G/zI\nWdn/AZMsixEoPme/5trd1JXTFdc7N5t7ChwJrzNEnFcZJwECAwEAAaN7MHkwDgYD\nVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFJEHcrjYiBFk\nD4ZRZIEl1uFqyE0wMB8GA1UdIwQYMBaAFJEHcrjYiBFkD4ZRZIEl1uFqyE0wMBYG\nA1UdEQQPMA2CC2V4YW1wbGUuY29tMA0GCSqGSIb3DQEBCwUAA4IBAQAGehO96QkD\nu+fcEOwwsbAzRDV6YM01iJSgVyW//K4Bm4/m7OjBsO+swUHrl/DcagvmHqd+2YmZ\ndayn9REhjyl7wc0VRTt/CMCkC2ZJ4MvOHYex3hm2voj09lzeCrbPGdxgnWRKAK+X\niRqsNrBbAcn+hU6ePjS+o+MZPWPeGAGh46lOBaUhZ+iASnHu+M9AK3Dl5yFCUyBu\nFe+sxQAoY+h/j3OGu8FH1gD802krMhN93PVVvF5Vr/eRYQwKLCA2BQvc+eQoau4o\nHxEVNwENpZSMYU8zZh5wAx5LjI9Ip2QWzuoLWlGddoJnHJoJj/46rKQRpLJLkf1I\ndAb0pmtctEIh\n-----END CERTIFICATE-----"
  ],
  "certificate": "-----BEGIN CERTIFICATE-----\nMIIDYTCCAkmgAwIBAgIUSngsxSTT3VuvQ5ySc7T2Z+fVzcwwDQYJKoZIhvcNAQEL\nBQAwJjEkMCIGA1UEAxMbZXhhbXBsZS5jb20gSW50ZXJtZWRpYXRlIENBMB4XDTI2\nMDIxNzAzMjgzN1oXDTI2MDIxODAzMjkwN1owHDEaMBgGA1UEAxMRbmdpbnguZXhh\nbXBsZS5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC3fAyOQf+T\n4p77Jhlt7RGzD+4BgmC05Dci47nGuL1VB5AG88ZnGKBj9g4l8fIPOo/rl61C/Rfu\nEm+tvxAMEU3khUWhdcl6EQyBEvGKHdkPMy+vj2binxDjIuQc8bVvF0BWCuhmNSGz\nveRyhXaEgWvvBDFDqPpJ37Q5OEe2S9WGWzj+6K4ij65oS6ubJvtVhZMRLqTq50kT\ntxHTlb7mguNCJBe7/AhZjV/bSiDxbZEE6RcCJBDPghNXstx6HVqdVWnVGxVF5ubX\naCmDAoQBiN8A93trXa2SjEzuvNwgYOO7LZf0Diu1yfvQXsvvT5+rZnLta8tHdN8h
\n7HwRs8xsA6NNAgMBAAGjgZAwgY0wDgYDVR0PAQH/BAQDAgOoMB0GA1UdJQQWMBQG\nCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUlUrOhfS/doP/FAznxL4+4Jbw\nKKcwHwYDVR0jBBgwFoAUQ49AdGQEqECW2yFp4kARMgBdH18wHAYDVR0RBBUwE4IR\nbmdpbnguZXhhbXBsZS5jb20wDQYJKoZIhvcNAQELBQADggEBAEVPQJfDPgJ5gzPt\n6xxTKhqpeIqf55KPuG82PPdhQAEpFa+8EN6/TbpdePgwxWbw2Fg2KrJrdUC78CV2\nTym0I4hOZTqJUntYm6Tybx1d3X9W2Gbmg0dIUs4KiHWhcu9kdeNFTBD1rnFgzKm3\nb3ozQL3nJIZab53NVneTN4HIXZIZ/hOBDtQhdxI8fhCw+8vL+X+UVLtkqqq+qUUu\nFf6kbYqp66joAug3d8ZEGoyVdSQM/RnO4V9IWJhh3Y1ZkA6azKkqM336bL5p7ZdY\njacCncecATLoplrkARDnA7CcwM3zfj5IT3VzT//fwyHI/o9AO8zH7SRtRQ6/LW9A\nFpK2hq8=\n-----END CERTIFICATE-----",
  "expiration": 1771385347,
  "issuing_ca": "-----BEGIN CERTIFICATE-----\nMIIDnzCCAoegAwIBAgIUd0ZhAmsb9n7PLHh1vz/zn0/FdGQwDQYJKoZIhvcNAQEL\nBQAwFjEUMBIGA1UEAxMLZXhhbXBsZS5jb20wHhcNMjUwOTEwMTg0NTAxWhcNMjYw\nOTEwMTg0NDUxWjAmMSQwIgYDVQQDExtleGFtcGxlLmNvbSBJbnRlcm1lZGlhdGUg\nQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDO7wSMHskO3S+vU/H/\ntJbd3h97FKaiuy89MSUt/HUKGa/tmfl7GHPvrxwt6aLIJxumg2oFoTJ5F0R7XX7r\nMBffGmTpIC9lrC98Zh1NkDOLYce0qlh6mVbUV7eX/jdiniPD9GB8n8aqMvokL4fA\ns12PE8PZNRKxvwrjn9m6CbfCcnsFFUe1N04auERvtUO5VCFYow0VJLkt+KMLGW+P\nkF+nRbyUoCyTo43kEIF+k5S9BfZvp7hivnfyeYMqx+kIJE1UY7ORXOoqT/XhHs9M\nZfOOlUFmC3isLwSoxCXSjP4+XsR1/yOgCezo13I1wmfSCNw9rKC44UZkfJQCbIAL\nWZobAgMBAAGjgdQwgdEwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8w\nHQYDVR0OBBYEFEOPQHRkBKhAltshaeJAETIAXR9fMB8GA1UdIwQYMBaAFJEHcrjY\niBFkD4ZRZIEl1uFqyE0wMDsGCCsGAQUFBwEBBC8wLTArBggrBgEFBQcwAoYfaHR0\ncDovLzEyNy4wLjAuMTo4MjAwL3YxL3BraS9jYTAxBgNVHR8EKjAoMCagJKAihiBo\ndHRwOi8vMTI3LjAuMC4xOjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOC\nAQEAcLKBm6m/w8jkWrBerQlVw/UPyyBrdEx0dtVMUL7chMVxCZntpF7tyRdV2cSz\nK2oy4HHRrM9Cp9B47Mwq8TA4gnKfq+c1KIy3kJyyOQQshQs1JFBdzBOU0NGxrmxZ\n0fBwP3DL3kT/2dx0fl7G59sjdlka0YHbLAAV6g5KOgTTj+/FUbWm7AnJs1ymPqHJ\njrKO2V8uvN2TD64w3d1N6mwF7lohw1U8mUZOhjylF5vdFtSOTJ0D+ByhgrGt2qbZ\nPOZiWBoV8gLDSsSgrR4tfjQt0iblSzIPj1c0nZO1Lh6ujCUASJkz16sAiK8YsZoc\n2OjJ9YuqYpzkoVZ39CPpV4xaig==\n-----END CERTIFICATE-----",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAt3wMjkH/k+Ke+yYZbe0Rsw/uAYJgtOQ3IuO5xri9VQeQBvPG\nZxigY/YOJfHyDzqP65etQv0X7hJvrb8QDBFN5IVFoXXJehEMgRLxih3ZDzMvr49m\n4p8Q4yLkHPG1bxdAVgroZjUhs73kcoV2hIFr7wQxQ6j6Sd+0OThHtkvVhls4/uiu\nIo+uaEurmyb7VYWTES6k6udJE7cR05W+5oLjQiQXu/wIWY1f20og8W2RBOkXAiQQ\nz4ITV7Lceh1anVVp1RsVRebm12gpgwKEAYjfAPd7a12tkoxM7rzcIGDjuy2X9A4r\ntcn70F7L70+fq2Zy7WvLR3TfIex8EbPMbAOjTQIDAQABAoIBABRXQDJqcUw9DKWI\nV7wD/WOobxjjvJd7z/uiMJot0291uIB3eJXn+P/xQH2cZi/3V1/QH3kUWG7KxG6y\nhl46x4kp7R+Ke0d4/ws1b77WsurTIITfP5H9UwCbLEa5KlqibT4cqh7f4liWw0NJ\nixYCyFW6/+shnyhJZdAMw9vFvxTMdWCpWqLAgGMUHDpCqXRoXUnwcg7qz8ck0w4e\nsKSuVUlkQi9RiJzyscagJkgvLTd2nsrAlAPMuVg1gGl9Bu65z8xWIDe5m2E+0EQV\ndDjpt5xlYn+sBI3/iJ3/wKlMMMlqLwZl2q7yWsX1s8DiqxYNFcag2QMySugL7cXp\nU4/vGVECgYEA0mhhTeihqfD0sLbQW8uggtpS+3+AifOCVkMjov618pDI3bn4PjYC\n2VQ1W5s6zYITlrQgvNYR57lTKFova+Om/6ww5sJtRvpLQg9y9hGmyrghkdwS5l/j\nlaE4+IYLqD+F7zdTTQ+e6gXPZxOBxamoyl/mxZkuhM/3l1SfIDOEh9MCgYEA3z4z\nujD8nKcaHfNFQA8Rrr3GDPKtH45a/eRK4FsIxZLntwobACxx58dso/fnHywQzkq/\nG6F2qRKBOepeA7wNFi0HPlP1u6uEfbxeKqErHctQYk+XTWYZqQ98s4ES9mlGTH4q\nyZ7NeDLvdPnVaqLhRrOHYkdpI4E2smdrQQMsVF8CgYEApiJ66kxMEeZLHplKzaBr\n3cZLjX9wW/ylJj2fDt01hxDhOYnUxDJbb4S5GNrpxEj39J/H1bLlsmU3jv4ewX6g\nZvJsLljIdim9cKzIJhlr7FcVUplFZxfBmG0TkdAttixqMacqpAc4gCoUSJwzdIJw\n31J34gAApiebpKbReliTRbcCgYEAv8ugA1os3aWPAaZMm7GWnos6iUtBQ7g5IqIt\nVj2/9oa0/wP2mJqWrewewWytq5FfSuza7bE10iIs1gYuCYVZtPCwpXLazwaXyLK6\nMGPROELB6AS7V+rdJutAVrQRB5UAqZ1Hw3rkylzwb45pNbmEVArPyLbTdIaB6JqD\nghJo1n8CgYBAh2kGBP1Vj5WnsIA28KkfgkImmHUtC9YXE+3tiImECN6vgfFU5p4V\nf0nlBjuYI2DyHm/cYR6LJRcRlV5ATrsVZP0LZBcrW4+RP1I/Z30ic9zQEIGoZDuD\nQYlK6kQRURBGurnq1yNPsyjEek3f3eQ1cHRqXPCS7cj3B/q92drL9A==\n-----END RSA PRIVATE KEY-----",
  "private_key_type": "rsa",
  "serial_number": "4a:78:2c:c5:24:d3:dd:5b:af:43:9c:92:73:b4:f6:67:e7:d5:cd:cc"
}
admin@i-0d9740ae82212691c:~$ jq -r .data.certificate cert.json > /etc/nginx/ssl/cert.pem
jq -r .data.private_key cert.json > /etc/nginx/ssl/key.pem
jq -r .data.issuing_ca cert.json > /etc/nginx/ssl/ca.pem
-bash: /etc/nginx/ssl/ca.pem: Permission denied
admin@i-0d9740ae82212691c:~$ sudo jq -r .data.certificate cert.json > /etc/nginx/ssl/cert.pem
admin@i-0d9740ae82212691c:~$ sudo jq -r .data.private_key cert.json > /etc/nginx/ssl/key.pem
admin@i-0d9740ae82212691c:~$ sudo jq -r .data.issuing_ca cert.json > /etc/nginx/ssl/ca.pem
-bash: /etc/nginx/ssl/ca.pem: Permission denied
admin@i-0d9740ae82212691c:~$ sudo jq -r .data.issuing_ca cert.json > /etc/nginx/ssl/ca.pem
-bash: /etc/nginx/ssl/ca.pem: Permission denied
admin@i-0d9740ae82212691c:~$ sudo su -
root@i-0d9740ae82212691c:~# jq -r .data.issuing_ca cert.json > /etc/nginx/ssl/ca.pem
jq: error: Could not open file cert.json: No such file or directory
root@i-0d9740ae82212691c:~# cd /home/admin/
root@i-0d9740ae82212691c:/home/admin# jq -r .data.issuing_ca cert.json > /etc/nginx/ssl/ca.pem
root@i-0d9740ae82212691c:/home/admin# exit
logout
admin@i-0d9740ae82212691c:~$ ls
agent  cert.json
admin@i-0d9740ae82212691c:~$ cat /etc/nginx/ssl/cert.pem /etc/nginx/ssl/ca.pem > /etc/nginx/ssl/fullchain.pem
-bash: /etc/nginx/ssl/fullchain.pem: Permission denied
admin@i-0d9740ae82212691c:~$ sudo cat /etc/nginx/ssl/cert.pem /etc/nginx/ssl/ca.pem > /etc/nginx/ssl/fullchain.pem
-bash: /etc/nginx/ssl/fullchain.pem: Permission denied
admin@i-0d9740ae82212691c:~$ sudo su -
root@i-0d9740ae82212691c:~# cat /etc/nginx/ssl/cert.pem /etc/nginx/ssl/ca.pem > /etc/nginx/ssl/fullchain.pem
root@i-0d9740ae82212691c:~# vim /etc/nginx/
conf.d/            fastcgi_params     koi-win            modules-available/ nginx.conf         scgi_params        sites-enabled/     ssl/               win-utf
fastcgi.conf       koi-utf            mime.types         modules-enabled/   proxy_params       sites-available/   snippets/          uwsgi_params
root@i-0d9740ae82212691c:~# vim /etc/nginx/nginx.conf
root@i-0d9740ae82212691c:~# vim /etc/nginx/ssl/
ca.pem         cert.pem       fullchain.pem  key.pem
root@i-0d9740ae82212691c:~# vim /etc/nginx/sites-enabled/default
root@i-0d9740ae82212691c:~# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
root@i-0d9740ae82212691c:~# systemctl reload nginx.service
root@i-0d9740ae82212691c:~#
logout
admin@i-0d9740ae82212691c:~$ !1
curl -v https://nginx.example.com
* Host nginx.example.com:443 was resolved.
* IPv6: (none)
* IPv4: 127.0.0.1
*   Trying 127.0.0.1:443...
* ALPN: curl offers h2,http/1.1
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
*  CAfile: /etc/ssl/certs/ca-certificates.crt
*  CApath: /etc/ssl/certs
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384 / X25519MLKEM768 / RSASSA-PSS
* ALPN: server accepted http/1.1
* Server certificate:
*  subject: CN=nginx.example.com
*  start date: Feb 17 03:28:37 2026 GMT
*  expire date: Feb 18 03:29:07 2026 GMT
*  subjectAltName: host "nginx.example.com" matched cert's "nginx.example.com"
*  issuer: CN=example.com Intermediate CA
*  SSL certificate verify ok.
*   Certificate level 0: Public key type RSA (2048/112 Bits/secBits), signed using sha256WithRSAEncryption
*   Certificate level 1: Public key type RSA (2048/112 Bits/secBits), signed using sha256WithRSAEncryption
*   Certificate level 2: Public key type RSA (2048/112 Bits/secBits), signed using sha256WithRSAEncryption
* Connected to nginx.example.com (127.0.0.1) port 443
* using HTTP/1.x
> GET / HTTP/1.1
> Host: nginx.example.com
> User-Agent: curl/8.14.1
> Accept: */*
>
* Request completely sent off
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
< HTTP/1.1 200 OK
< Server: nginx
< Date: Tue, 17 Feb 2026 03:35:05 GMT
< Content-Type: text/html
< Content-Length: 7
< Last-Modified: Wed, 10 Sep 2025 18:43:54 GMT
< Connection: keep-alive
< ETag: "68c1c6ea-7"
< Accept-Ranges: bytes
<
Hello!
* Connection #0 to host nginx.example.com left intact
admin@i-0d9740ae82212691c:~$ agent/check.sh
NOadmin@i-0d9740ae82212691c:~$ Connection to 18.188.250.168 closed by remote host.
```