using System.Diagnostics;

namespace RedisService
{
    class Program
    {
        static async Task Main(string[] args)
        {
            string configFilePath = "redis.conf";

            if (args.Length > 1 && args[0] == "-c")
            {
                configFilePath = args[1];
            }

            IHost host = Host.CreateDefaultBuilder()
                .UseWindowsService()
                .ConfigureServices((hostContext, services) =>
                {
                    services.AddHostedService(serviceProvider =>
                        new RedisService(configFilePath));
                })
                .Build();

            await host.RunAsync();
        }
    }

    public class RedisService(string configFilePath) : BackgroundService
    {
        private Process? _redisProcess;
        private readonly ILogger<RedisService> _logger;

        public RedisService(string configFilePath, ILogger<RedisService>? logger = null) 
            : this(configFilePath)
        {
            _logger = logger ?? Microsoft.Extensions.Logging.Abstractions.NullLogger<RedisService>.Instance;
        }

        public override async Task StartAsync(CancellationToken stoppingToken)
        {
            try
            {
                var basePath = AppContext.BaseDirectory;

                if (!Path.IsPathRooted(configFilePath))
                {
                    configFilePath = Path.Combine(basePath, configFilePath);
                }

                configFilePath = Path.GetFullPath(configFilePath);

                if (!File.Exists(configFilePath))
                {
                    _logger.LogWarning("Config file not found: {ConfigPath}", configFilePath);
                }

                var diskSymbol = configFilePath[..configFilePath.IndexOf(":")];
                var fileConf = configFilePath.Replace(diskSymbol + ":", "/cygdrive/" + diskSymbol).Replace("\\", "/");

                string fileName = Path.Combine(basePath, "redis-server.exe");
                if (!File.Exists(fileName))
                {
                    _logger.LogError("Redis server executable not found: {FileName}", fileName);
                    throw new FileNotFoundException($"Redis server executable not found: {fileName}");
                }

                fileName = fileName.Replace("\\", "/");
                string arguments = $"\"{fileConf}\"";

                ProcessStartInfo processStartInfo = new(fileName, arguments)
                {
                    WorkingDirectory = basePath,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };

                _redisProcess = Process.Start(processStartInfo);

                if (_redisProcess == null)
                {
                    _logger.LogError("Failed to start Redis process");
                    throw new InvalidOperationException("Failed to start Redis process");
                }

                _logger.LogInformation("Redis service started with PID: {ProcessId}", _redisProcess.Id);

                _redisProcess.OutputDataReceived += (sender, args) =>
                {
                    if (!string.IsNullOrEmpty(args.Data))
                        _logger.LogInformation("Redis: {Output}", args.Data);
                };

                _redisProcess.ErrorDataReceived += (sender, args) =>
                {
                    if (!string.IsNullOrEmpty(args.Data))
                        _logger.LogError("Redis Error: {Error}", args.Data);
                };

                _redisProcess.BeginOutputReadLine();
                _redisProcess.BeginErrorReadLine();

                await base.StartAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to start Redis service");
                throw;
            }
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            try
            {
                while (!stoppingToken.IsCancellationRequested && _redisProcess != null && !_redisProcess.HasExited)
                {
                    await Task.Delay(1000, stoppingToken);
                }

                if (_redisProcess?.HasExited == true)
                {
                    _logger.LogWarning("Redis process exited unexpectedly with code: {ExitCode}", _redisProcess.ExitCode);
                }
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("Redis service execution cancelled");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during Redis service execution");
            }
        }

        public override async Task StopAsync(CancellationToken stoppingToken)
        {
            try
            {
                if (_redisProcess != null && !_redisProcess.HasExited)
                {
                    _logger.LogInformation("Stopping Redis process...");
                    
                    _redisProcess.CloseMainWindow();
                    
                    if (!_redisProcess.WaitForExit(5000))
                    {
                        _logger.LogWarning("Redis process did not exit gracefully, forcing termination");
                        _redisProcess.Kill();
                    }

                    _redisProcess.Dispose();
                    _redisProcess = null;
                    _logger.LogInformation("Redis service stopped");
                }

                await base.StopAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error stopping Redis service");
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                _redisProcess?.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
