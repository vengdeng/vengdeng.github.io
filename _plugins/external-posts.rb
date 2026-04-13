require 'feedjira'
require 'httparty'
require 'jekyll'

module ExternalPosts
  class ExternalPostsGenerator < Jekyll::Generator
    safe true
    priority :high

    def generate(site)
      return if site.config['external_sources'].nil?

      site.config['external_sources'].each do |src|
        Jekyll.logger.info('ExternalPosts:', "Fetching posts from #{src['name']}")
        xml = fetch_feed(src)
        next if xml.nil?

        feed = Feedjira.parse(xml)
        feed.entries.each do |e|
          slug = e.title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
          path = site.in_source_dir("_posts/#{slug}.md")
          doc = Jekyll::Document.new(
            path, { :site => site, :collection => site.collections['posts'] }
          )
          doc.data['external_source'] = src['name']
          doc.data['feed_content'] = e.content
          doc.data['title'] = e.title.to_s
          doc.data['description'] = e.summary
          doc.data['date'] = e.published
          doc.data['redirect'] = e.url
          site.collections['posts'].docs << doc
        end
      end
    end

    private

    def fetch_feed(src)
      response = HTTParty.get(src['rss_url'], timeout: 10)
      return response.body if response.success?

      Jekyll.logger.warn(
        'ExternalPosts:',
        "Skipping #{src['name']} because #{src['rss_url']} returned HTTP #{response.code}"
      )
      nil
    rescue StandardError => e
      Jekyll.logger.warn(
        'ExternalPosts:',
        "Skipping #{src['name']} because the feed could not be fetched (#{e.class}: #{e.message})"
      )
      nil
    end
  end

end
