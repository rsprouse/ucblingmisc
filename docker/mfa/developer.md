# Notes and documentation for the developer of the `mfa` container

As of May 2021 the current version of the Montreal Forced Aligner is [`v1.0.1`](https://github.com/MontrealCorpusTools/Montreal-Forced-Aligner/releases/tag/v1.0.1). However, the documentation on the current MFA website describes version 2, which is still alpha.

The `v1.0.1` version is used to build this container, and it includes fixes for known bugs. See `Dockerfile` for links to the issues where the bugs are described.

## Building

To create the `mfa` container do:

```bash
cd /path/to/Dockerfile
docker build --tag phonlab/mfa:1.0.1 .
```

## Pushing to the container registry

To push an image to the container registry on AWS, an IAM user must exist with permission to make changes to the registry. The `aws_access_key_id` and `aws_secret_access_key` values for this user can be stored in the `credentials` file for use with the AWS cli. Once the IAM user is set up and credentials stored, build the image as described above and then do:

```bash
# Retrieve an authentication token and authenticate your Docker client to your registry.
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/ucblx

# Tag your image so you can push the image to this repository.
docker tag phonlab/mfa:1.0.1 public.ecr.aws/ucblx/phonlab/mfa:1.0.1

# Push the image to the AWS repository.
docker push public.ecr.aws/ucblx/phonlab/mfa:1.0.1
```

