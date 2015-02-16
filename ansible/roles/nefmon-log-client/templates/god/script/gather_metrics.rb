require 'fluent-logger'

Fluent::Logger::FluentLogger.open(
  nil,
  :host => '{{ tdagent_host }}',
  :port => {{ tdagent_port }}
)
$root_tag = '{{ nefmon_root_tag }}'
$server_label = '{{ nefmon_server_label }}'

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
      Fluent::Logger.post("#{$root_tag}.#{$server_label}.os.cpu", metrics)
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
      Fluent::Logger.post("#{$root_tag}.#{$server_label}.os.loadavg", metrics)
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
      Fluent::Logger.post("#{$root_tag}.#{$server_label}.os.mem_usage", metrics)
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
      Fluent::Logger.post("#{$root_tag}.#{$server_label}.os.disk_usage", metrics)
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
      Fluent::Logger.post("#{$root_tag}.#{$server_label}.os.iostat", metrics)
    }
  }

  # network
  Thread.new {
    # we'll capture eth0 in this sample.
    IO.popen('vnstat -i eth0 -tr 5') { |io|
      lines = io.readlines
      in_info = lines[3].strip.split(/\s+/)
      out_info = lines[4].strip.split(/\s+/)

      #outputs will be in Gbit, Mbit, or kbit. so unify it to Kbit.
      in_raw = in_info[1].to_f
      in_unit = in_info[2][0].upcase
      multi = in_unit == "G" ? 1000000.0 : (in_unit == "M" ? 1000.0 : 1.0)
      in_kbit_ps = in_raw * multi

      out_raw = out_info[1].to_f
      out_unit = out_info[2][0].upcase
      multi = out_unit == "G" ? 1000000.0 : (out_unit == "M" ? 1000.0 : 1.0)
      out_kbit_ps = out_raw * multi

      metrics = {
        "in_packet_ps"  => in_info[3].to_i,
        "out_packet_ps" => out_info[3].to_i,
        "in_kbit_ps"    => in_kbit_ps,
        "out_kbit_ps"   => out_kbit_ps
      }
      Fluent::Logger.post("#{$root_tag}.#{$server_label}.os.eth0", metrics)
    }
  }
end

while true do
  gather_metrics()
  sleep 10
end
