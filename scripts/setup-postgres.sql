CREATE USER issuer_backend WITH PASSWORD 'secret';
CREATE DATABASE grnet_eudiw_issuer OWNER issuer_backend;
GRANT ALL PRIVILEGES ON DATABASE grnet_eudiw_issuer TO issuer_backend;
