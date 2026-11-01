# Custom Atlantis image with Terraform preinstalled
# Base: official Atlantis image (force AMD64 platform)
FROM --platform=linux/amd64 ghcr.io/runatlantis/atlantis:v0.35.1

# Switch to root to install/copy binaries
USER root

# Copy pre-downloaded Terraform binary (1.13.1) from build context
# Expecting file at: containers/atlantis/terraform
COPY terraform /usr/local/bin/terraform-1.13.1

# Ensure the binary is executable
# Replace the default terraform symlink to point to 1.13.1
RUN chmod +x /usr/local/bin/terraform-1.13.1 \
 && rm -f /usr/local/bin/terraform \
 && mkdir -p /usr/local/bin/tf/versions/1.13.1 \
 && cp /usr/local/bin/terraform-1.13.1 /usr/local/bin/tf/versions/1.13.1/terraform \
 && ln -sf /usr/local/bin/tf/versions/1.13.1/terraform /usr/local/bin/terraform

# Verify terraform version at startup and use the correct binary
RUN /usr/local/bin/terraform version

# Entrypoint/CMD remain the same as the base image (runs `atlantis server`)
ENTRYPOINT ["atlantis","server","--tf-download=false"]
USER atlantis