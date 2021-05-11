# Montreal Forced Aligner
FROM python:3.9-slim-buster
ENV APP_HOME /app
WORKDIR $APP_HOME

# libopenblas-base is required to fix the broken libopenblas in the mfa release file.
# See issue 91 mentioned below.
RUN apt-get update && apt-get install -qq -y \
    libopenblas-base \
    sox \
    vim \
    wget

# Get MFA 1.0.1 and apply fixes for:
# https://github.com/MontrealCorpusTools/Montreal-Forced-Aligner/issues/91
# https://github.com/MontrealCorpusTools/Montreal-Forced-Aligner/issues/109
RUN wget https://github.com/MontrealCorpusTools/Montreal-Forced-Aligner/releases/download/v1.0.1/montreal-forced-aligner_linux.tar.gz && \
    tar xzvf montreal-forced-aligner_linux.tar.gz && \
    rm ${APP_HOME}/montreal-forced-aligner/lib/thirdparty/bin/libopenblas.so.0 && \
    ln -s /usr/lib/x86_64-linux-gnu/libopenblas.so.0 ${APP_HOME}/montreal-forced-aligner/lib/thirdparty/bin/libopenblas.so.0 && \
    ln -s ${APP_HOME}/montreal-forced-aligner/lib/libpython3.6m.so.1.0 ${APP_HOME}/montreal-forced-aligner/lib/libpython3.6m.so && \
    rm montreal-forced-aligner_linux.tar.gz

# Add executables to a dir in $PATH
RUN find ${APP_HOME}/montreal-forced-aligner/bin -type l -exec ln -s {} /usr/local/bin \;

# Add mfa_align_single script
RUN cd /usr/local/bin && wget https://raw.githubusercontent.com/rsprouse/ucblingmisc/master/python/mfa_align_single && chmod +x mfa_align_single
