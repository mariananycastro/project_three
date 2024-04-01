
FROM ruby:3.3.0

WORKDIR /app
COPY . /app
RUN bundle install

# default port for Sinatra
EXPOSE 4567

CMD ["/bin/bash"]
# CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]
