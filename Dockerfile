FROM ubuntu:jammy

RUN : \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dumb-init \
        python3.10 \
        python3-distutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV \
    PATH=/venv/bin:$PATH \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUALENV_ACTIVATORS=bash \
    VIRTUALENV_NO_PERIODIC_UPDATE=1 \
    VIRTUALENV_PIP=embed \
    VIRTUALENV_SETUPTOOLS=embed \
    VIRTUALENV_WHEEL=embed
RUN : \
    && curl --silent --location --output /tmp/virtualenv.pyz https://bootstrap.pypa.io/virtualenv.pyz \
    && python3.10 /tmp/virtualenv.pyz /venv \
    && rm /tmp/virtualenv.pyz

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
