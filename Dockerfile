FROM ruby:3.2.0

#ENV APP_USER myuser
#ENV APP_HOME /home/${APP_USER}/app
ENV PORT 4000

#RUN useradd --create-home ${APP_USER}
#USER ${APP_USER}
RUN mkdir /app

WORKDIR /app

COPY . /app

ENV BUNDLE_GEMFILE=/app/Gemfile \
  BUNDLE_JOBS=2 \
  BUNDLE_PATH=/root/bundle

RUN bundle install

EXPOSE $PORT

ENTRYPOINT [ "bundle", "exec" ]
CMD [ "jekyll", "serve", "-H", "0.0.0.0", "--future" ]