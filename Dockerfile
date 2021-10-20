FROM registry.ci.openshift.org/openshift/release:golang-1.16 AS builder
ENV GOFLAGS=-mod=mod
ENV VERSION="v1.22.0"
WORKDIR /go/src/github.com/redhat-ztp/openshift-ai-image-backup

RUN yum -y install skopeo && yum -y install wget
RUN useradd skopeo

# Setup skopeo's uid/guid entries
RUN echo skopeo:100000:65536 > /etc/subuid
RUN echo skopeo:100000:65536 > /etc/subgid

# install crictl
RUN wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz \
         && tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C . \
         && rm -f crictl-$VERSION-linux-amd64.tar.gz


# Bring in the go dependencies before anything else so we can take
# advantage of caching these layers in future builds.
COPY go.mod go.mod
COPY go.sum go.sum
RUN go mod download

COPY . .
RUN make build

FROM quay.io/centos/centos:stream8

COPY --from=builder /go/src/github.com/redhat-ztp/openshift-ai-image-backup/bin/openshift-ai-image-backup /usr/bin/openshift-ai-image-backup
COPY --from=builder /go/src/github.com/redhat-ztp/openshift-ai-image-backup/crictl /usr/bin/crictl

# install jq
RUN yum -y install jq

# Point to the Authorization file
ENV REGISTRY_AUTH_FILE=/tmp/auth.json

ENTRYPOINT ["/usr/bin/openshift-ai-image-backup"]
