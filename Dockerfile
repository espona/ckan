# See CKAN docs on installation from Docker Compose on usage
FROM debian:jessie
MAINTAINER Open Knowledge

# Install required system packages
RUN apt-get -q -y update \
    && DEBIAN_FRONTEND=noninteractive apt-get -q -y upgrade \
    && apt-get -q -y install \
        python-dev \
        python-pip \
        python-virtualenv \
        python-wheel \
        libpq-dev \
        libxml2-dev \
        libxslt-dev \
        libgeos-dev \
        libssl-dev \
        libffi-dev \
        postgresql-client \
        build-essential \
        git-core \
        vim \
        nano \
        wget \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*

# Define environment variables
ENV CKAN_HOME /usr/lib/ckan
ENV CKAN_VENV $CKAN_HOME/venv
ENV CKAN_CONFIG /etc/ckan
ENV CKAN_STORAGE_PATH=/var/lib/ckan

# Create ckan user
RUN useradd -r -u 900 -m -c "ckan account" -d $CKAN_HOME -s /bin/false ckan

# Setup virtual environment for CKAN
RUN mkdir -p $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH && \
    virtualenv $CKAN_VENV && \
    ln -s $CKAN_VENV/bin/pip /usr/local/bin/ckan-pip &&\
    ln -s $CKAN_VENV/bin/python /usr/local/bin/ckan-python &&\
    ln -s $CKAN_VENV/bin/paster /usr/local/bin/ckan-paster

# Add CKAN config
ADD config/*.ini $CKAN_CONFIG

# Setup CKAN
ADD source $CKAN_VENV/src
RUN ckan-pip install -U pip && \
    ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirement-setuptools.txt && \
    ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirements.txt && \
    ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/dev-requirements.txt && \
    ckan-pip install -e $CKAN_VENV/src/ckan/ && \
    ln -s $CKAN_VENV/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini && \
    cp -v $CKAN_VENV/src/ckan/contrib/docker/ckan-entrypoint.sh /ckan-entrypoint.sh && \
    chmod +x /ckan-entrypoint.sh && \
    chown -R ckan:ckan $CKAN_HOME $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH

RUN echo "Check whether config was copied and with ckan as owner"
RUN ls -lisah $CKAN_CONFIG

# Setup extensions
RUN echo "Check directory structure"
RUN ls $CKAN_VENV/src

WORKDIR $CKAN_VENV/src/ckanext-datacite_publication
RUN ckan-python setup.py develop  && \
    ckan-pip install --upgrade --no-cache-dir -r requirements.txt

WORKDIR $CKAN_VENV/src/ckanext-envidat_theme
RUN ckan-python setup.py develop

WORKDIR $CKAN_VENV/src/ckanext-passwordless
RUN ckan-python setup.py develop  && \
    ckan-pip install --upgrade --no-cache-dir -r requirements.txt

WORKDIR $CKAN_VENV/src/ckanext-package_converter
RUN ckan-python setup.py develop  && \
    ckan-pip install --upgrade --no-cache-dir -r requirements.txt

WORKDIR $CKAN_VENV/src/ckanext-scheming
RUN ckan-python setup.py develop  && \
    ckan-pip install --upgrade --no-cache-dir -r requirements.txt

WORKDIR $CKAN_VENV/src/ckanext-restricted
RUN ckan-python setup.py develop

WORKDIR $CKAN_VENV/src/ckanext-repeating
RUN ckan-python setup.py develop

WORKDIR $CKAN_VENV/src/ckanext-composite
RUN ckan-python setup.py develop

WORKDIR $CKAN_VENV/src/ckanext-hierarchy
RUN ckan-python setup.py develop

WORKDIR $CKAN_VENV/src/ckanext-spatial
RUN ckan-python setup.py develop && \
    ckan-pip install --upgrade --no-cache-dir -r pip-requirements.txt

WORKDIR $CKAN_VENV/src/ckanext-oaipmh_repository
RUN ckan-python setup.py develop

WORKDIR $CKAN_VENV/src/ckan
run pwd

ENTRYPOINT ["/ckan-entrypoint.sh"]

USER ckan
EXPOSE 5000

CMD ["ckan-paster","serve", "/etc/ckan/development.ini"]
