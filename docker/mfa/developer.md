# Notes and documentation for the developer of the `mfa` container

As of May 2021 the current version of the Montreal Forced Aligner is [`v1.0.1`](https://github.com/MontrealCorpusTools/Montreal-Forced-Aligner/releases/tag/v1.0.1). However, the documentation on the current MFA website describes version 2, which is still alpha.

The `v1.0.1` version is used to build this container, and it includes fixes for known bugs. See `Dockerfile` for links to the issues where the bugs are described.

## Building

To create the `mfa` container do:

```bash
cd /path/to/Dockerfile
docker build --tag mfa:1.0.1 .
```

If you haven't cloned this repo on your build machine you can download the `Dockerfile` from this folder in order to run the build.

Sometimes it is necessary to add `--no-cache` to pick up changes in an external resource, e.g. if the `mfa_align_single` script has changed.

```bash
docker build --tag mfa:1.0.1 --no-cache .
```

## Pushing to the container registry

To push an image to the container registry on AWS, an IAM user must exist with permission to make changes to the registry. The `aws_access_key_id` and `aws_secret_access_key` values for this user can be stored in the `credentials` file for use with the AWS cli. Once the IAM user is set up and credentials stored, build the image as described above and then do:

```bash
# Retrieve an authentication token and authenticate your Docker client to your registry.
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/w5x7g6y7

# Tag your image so you can push the image to this repository.
docker tag mfa:1.0.1 public.ecr.aws/w5x7g6y7/mfa:1.0.1

# Push the image to the AWS repository.
docker push public.ecr.aws/w5x7g6y7/mfa:1.0.1
```

