# API + R (survey models). Set Railway root directory to: macro_goal_app/backend
FROM rocker/r-ver:4.4.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
  && rm -rf /var/lib/apt/lists/* \
  && python3 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Rocker `r-ver` sets CRAN to Posit prebuilt binaries for this image’s Ubuntu.
# Passing only `cloud.r-project.org` forces long source compiles and often hits Railway’s build timeout.
RUN Rscript -e 'options(Ncpus = min(8L, max(1L, parallel::detectCores()))); install.packages(c("survey", "car"), verbose = TRUE)'

COPY . .

EXPOSE 8000

CMD ["/bin/sh", "-c", "exec uvicorn app:app --host 0.0.0.0 --port ${PORT:-8000}"]
