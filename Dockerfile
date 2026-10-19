FROM ruby:3.4-slim
ARG RELEASE=dev
ENV RELEASE=${RELEASE}
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*
COPY Gemfile .
RUN bundle install
COPY app.rb .
EXPOSE 8080
CMD ["ruby", "app.rb", "serve"]
