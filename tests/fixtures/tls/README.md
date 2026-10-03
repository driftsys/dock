# TLS test fixtures

The CA and localhost server certificate and private key are test data. They
grant access to no service. The CA private key is not stored here. The
certificate includes localhost and 127.0.0.1 and expires in 2036. Local HTTPS
tests first reject it, then import the CA with dock-bootstrap.
