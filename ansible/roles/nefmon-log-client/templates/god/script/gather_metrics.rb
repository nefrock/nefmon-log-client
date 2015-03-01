class MetricsCollector
  require 'fluent-logger'

  def initialize()
    Fluent::Logger::FluentLogger.open(
      nil,
      :host => '{{ tdagent_host }}',
      :port => {{ tdagent_port }}
    )

    @root_tag = '{{ nefmon_root_tag }}'
    @app_tag = '{{ nefmon_app_tag }}'
    @server_tag = '{{ nefmon_server_tag }}'

    @interval = 10

    # we'll capture eth0 in this sample.
    @nw_target_interface = 'eth0'
    @nw_metrics = nil
  end

  def start()
    @nw_metrics = fetchNetworkMetrics()

    while true do
      sleep @interval
      gather_metrics()
    end
  end

  def gather_metrics()
    # cpu
    Thread.new {
      IO.popen('vmstat 5 2') { |io|
        cpu_info = io.readlines[3].strip.split(/\s+/)
        metrics = {
          "usr"    => cpu_info[12].to_i,
          "sys"    => cpu_info[13].to_i,
          "idle"   => cpu_info[14].to_i,
          "iowait" => cpu_info[15].to_i,
          "steal"  => cpu_info[16].to_i
        }
        Fluent::Logger.post("#{@root_tag}.#{@app_tag}.#{@server_tag}.os.cpu", metrics)
      }
    }

    # load average
    Thread.new {
      IO.popen('cat /proc/loadavg') { |io|
        la_info = io.read.strip.split(/\s+/)
        metrics = {
          "one"     => la_info[0].to_f,
          "five"    => la_info[1].to_f,
          "fifteen" => la_info[2].to_f
        }
        Fluent::Logger.post("#{@root_tag}.#{@app_tag}.#{@server_tag}.os.loadavg", metrics)
      }
    }

    # memory usage
    Thread.new {
      # in megabytes
      IO.popen('free -m') { |io|
        mem_info = io.readlines[1].strip.split(/\s+/)
        metrics = {
          "total" => mem_info[1].to_i,
          "used"  => mem_info[2].to_i
        }
        Fluent::Logger.post("#{@root_tag}.#{@app_tag}.#{@server_tag}.os.mem_usage", metrics)
      }
    }

    # disk usage
    Thread.new {
      IO.popen('df | grep dev') { |io|
        lines = io.readlines
        # this sample only cares about the first device and ignores the rest.
        # modify it according to your needs.
        disk_info = lines[0].strip.split(/\s+/)
        metrics = {
          #in gigabytes
          "total" => (disk_info[1].to_i / 1024.0 / 1024.0).round(2),
          "used"  => (disk_info[2].to_i / 1024.0 / 1024.0).round(2)
        }
        Fluent::Logger.post("#{@root_tag}.#{@app_tag}.#{@server_tag}.os.disk_usage", metrics)
      }
    }

    # iostat
    Thread.new {
      IO.popen('iostat -dkxy 5 1') { |io|
        iostat = io.readlines[3].strip.split(/\s+/)
        metrics = {
          "r_ps"   => iostat[3].to_f,
          "w_ps"   => iostat[4].to_f,
          "rkb_ps" => iostat[5].to_f,
          "wkb_ps" => iostat[6].to_f,
          "await"  => iostat[9].to_f, #millisec
          "p_util" => iostat[11].to_f  #percentage
        }
        Fluent::Logger.post("#{@root_tag}.#{@app_tag}.#{@server_tag}.os.iostat", metrics)
      }
    }

    # network
    Thread.new {
      nw_prev = @nw_metrics
      @nw_metrics = fetchNetworkMetrics()

      prev = nw_prev[@nw_target_interface]
      current = @nw_metrics[@nw_target_interface]
      # Kbit/s
      rx_kbit = (current["rx_bytes"] - prev["rx_bytes"]).to_f / 1000 * 8 / @interval
      tx_kbit = (current["tx_bytes"] - prev["tx_bytes"]).to_f / 1000 * 8 / @interval
      rx_packets = (current["rx_pkts"] - prev["rx_pkts"]).to_f / @interval
      tx_packets = (current["tx_pkts"] - prev["tx_pkts"]).to_f / @interval

      metrics = {
        "in_kbit_ps"    => rx_kbit.round(2),
        "out_kbit_ps"   => tx_kbit.round(2),
        "in_packet_ps"  => rx_packets.round(2),
        "out_packet_ps" => tx_packets.round(2)
      }
      Fluent::Logger.post("#{@root_tag}.#{@app_tag}.#{@server_tag}.os.#{@nw_target_interface}", metrics)
    }
  end

  private
    def fetchNetworkMetrics
      ret = {}
      cmd = "cat /proc/net/dev | grep #{@nw_target_interface}"
      cmd_result = `#{cmd}`.strip
      lines = cmd_result.split("\n")
      lines.each do |line|
        if_name, rest = line.strip.split(":")
        next if rest == nil

        stat_values = rest.strip.split(/\s+/)
        ret[if_name] = {
          "rx_bytes" => stat_values[0].to_i,
          "rx_pkts" => stat_values[1].to_i,
          "tx_bytes" => stat_values[8].to_i,
          "tx_pkts" => stat_values[9].to_i,
        }
      end
      return ret
    end
end

MetricsCollector.new.start()
