module Intrigue
module Strategy
  class AssetDiscovery < Intrigue::Strategy::Base

    def self.metadata
      {
        :name => "asset_discovery",
        :pretty_name => "Asset Discovery",
        :passive => false,
        :authors => ["jcran"],
        :description => "This strategy performs a network recon and enumeration. Suggest starting with a DnsRecord or NetBlock."
      }
    end

    def self.recurse(entity, task_result)

      if entity.type_string == "FtpServer"
        start_recursive_task(task_result,"ftp_banner_grab",entity)

      elsif entity.type_string == "DnsRecord"
        ### DNS Subdomain Bruteforce
        # Do a big bruteforce if the size is small enough
        if (entity.name.split(".").length < 3)

          # Sublister API
          start_recursive_task(task_result,"search_sublister", entity, [
            {"name" => "extract_pattern", "value" => "#{task_result.scan_result.base_entity.name}"}])

          # CRT Scraper
          start_recursive_task(task_result,"search_crt", entity, [
            {"name" => "extract_pattern", "value" => "#{task_result.scan_result.base_entity.name}"}])

          # Threatcrowd API... skip resolutions, as we probably don't want old
          # data for this use case
          start_recursive_task(task_result,"search_threatcrowd", entity, [
            {"name" => "gather_resolutions", "value" => true },
            {"name" => "gather_subdomains", "value" => true },
            {"name" => "extract_pattern", "value" => "#{task_result.scan_result.base_entity.name}"}])

          start_recursive_task(task_result,"dns_brute_sub",entity,[
            {"name" => "use_file", "value" => true },
            {"name" => "threads", "value" => 1 }])

        else
          # otherwise do something a little faster
          start_recursive_task(task_result,"dns_brute_sub",entity,[])
        end

      elsif entity.type_string == "IpAddress"

        # Prevent us from hammering on whois services
        unless ( entity.created_by?("net_block_expand"))
          start_recursive_task(task_result,"whois",entity)
        end

        start_recursive_task(task_result,"nmap_scan",entity)

      elsif entity.type_string == "String"
        # Search, only snag the top result
        start_recursive_task(task_result,"search_bing",entity,[{"name"=> "max_results", "value" => 1}])

      elsif entity.type_string == "NetBlock"

        # Make sure it's small enough not to be disruptive, and if it is, scan it. also skip ipv6/
        if ! entity.name =~ /::/
          start_recursive_task(task_result,"masscan_scan",entity,[{"name"=> "port", "value" => 80}])
          start_recursive_task(task_result,"masscan_scan",entity,[{"name"=> "port", "value" => 443}])
          start_recursive_task(task_result,"masscan_scan",entity,[{"name"=> "port", "value" => 8443}])
        else
          task_result.log "Cowardly refusing to scan this netblock."
        end

      elsif entity.type_string == "Uri"

        #start_recursive_task(task_result,"uri_screenshot",entity)

        # Check for exploitable URIs, but don't recurse on things we've already found
        start_recursive_task(task_result,"uri_brute", entity, [
          {"name"=> "threads", "value" => 1},
          {"name" => "user_list", "value" => "admin,test,server-status,.svn,.git,wp-config.php,config.php,configuration.php,LocalSettings.php,mediawiki/LocalSettings.php,mt-config.cgi,mt-static/mt-config.cgi,settings.php,.htaccess,config.bak,config.php.bak,config.php,#config.php#,config.php.save,.config.php.swp,config.php.swp,config.php.old"}])

        unless (entity.created_by?("uri_brute") || entity.created_by?("uri_spider") )

          ## Grab the SSL Certificate
          start_recursive_task(task_result,"uri_gather_ssl_certificate",entity) if entity.name =~ /^https/

          ## Super-lite spider, looking for metadata
          start_recursive_task(task_result,"uri_spider",entity,[
              {"name" => "max_pages", "value" => 50 },
              {"name" => "extract_dns_records", "value" => true },
              {"name" => "extract_dns_record_pattern", "value" => "#{task_result.scan_result.base_entity.name}"}])

        end
      else
        task_result.log "No actions for entity: #{entity.type}##{entity.name}"
        return
      end
    end

end
end
end
