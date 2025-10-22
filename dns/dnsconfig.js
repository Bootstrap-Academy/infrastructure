// @ts-check
/// <reference path="types-dnscontrol.d.ts" />

var REG_NONE = NewRegistrar("none");
var DSP_CLOUDFLARE = NewDnsProvider("cloudflare");

var prod4 = "49.13.80.22";
var prod6 = "2a01:4f8:c17:ad51::";

var test4 = "49.13.123.1";
var test6 = "2a01:4f8:c013:5e5f::";

D(
  "bootstrap.academy",
  REG_NONE,
  DnsProvider(DSP_CLOUDFLARE),
  DefaultTTL(1),

  ALIAS("@", "frontend-prod-2ik.pages.dev.", CF_PROXY_ON),
  ALIAS("admin", "bootstrap-academy-admin-prod.pages.dev.", CF_PROXY_ON),

  ALIAS("test", "bootstrap-academy-frontend.pages.dev.", CF_PROXY_ON),
  ALIAS("admin.test", "bootstrap-academy-admin.pages.dev.", CF_PROXY_ON),

  CNAME("static", "static.the-morpheus.de."),

  A("api", prod4),
  AAAA("api", prod6),

  A("api.test", test4),
  AAAA("api.test", test6),

  A("cache", prod4),
  AAAA("cache", prod6),

  A("glitchtip", prod4),
  AAAA("glitchtip", prod6),

  A("sandkasten", prod4),
  AAAA("sandkasten", prod6),

  MX("@", 10, "www79.your-server.de."),
  TXT("@", "v=spf1 +a +mx ~all"),
  TXT(
    "_dmarc",
    "v=DMARC1; p=quarantine; ruf=mailto:infrastructure@the-morpheus.de; fo=1;",
  ),
  TXT(
    "default2201._domainkey",
    '"v=DKIM1; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtFavscLzyh8amevkLg0jR" "Ivb0of7aPAnxzUjwAfQ6mmN/w5kjLQXADIsPxhMiCIa61tLltJ+2od/DAESton/RZtLUaQlHQ/y9" "QtNvR/Pe6yQf2xsi2pOoWe5jyVhHsRTToCevSL057x/RV76sqjKPx2QnCENGPo+OiSSjArh9UJ5V" "Iyii4t429Lp3ISGnYx5owFKHzPkCfAez/JDVugxpfOTykL5v5BlYv/z9QR7GgxwHiYhaOH5xG5GW" "UUq/65MErn9+yNUDx1lesZ4Q7J6zy5yfvfTE4gc7bs1JN1sjlr8Psh0A7EogOa+1l1W0frfYPsR1" "5LlOrmt0QqhHBEHhQIDAQAB"',
  ),

  CNAME("autoconfig", "mail.your-server.de."),
  SRV("_autodiscover._tcp", 0, 100, 443, "mail.your-server.de."),
  SRV("_imaps._tcp", 0, 100, 993, "mail.your-server.de."),
  SRV("_pop3s._tcp", 0, 100, 995, "mail.your-server.de."),
  SRV("_submission._tcp", 0, 100, 587, "mail.your-server.de."),

  TXT(
    "@",
    "google-site-verification=Re2IfJbx--PaEfLiPI2uLa3c0au3iPgf2NC2eKR7meg",
  ),

  AAAA("www", "100::", CF_PROXY_ON),
);
