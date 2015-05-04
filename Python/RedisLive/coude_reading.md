## 配置文件 

RedisServers： the redis instances you want to monitor.
RedisStatsServer： the redis instance you will use to store RedisLive data (this redis instance is different from the redis instances you are monitoring).
passwords： can be added as an optional parameter for any redis instance

if you don't have a spare redis instance to use to store Redis Live data, then you can configure to use sqlite by changing "DataStoreType" : "sqlite"

## Start RedisLive

- start the monitoring script ./redis-monitor.py --duration=120 duration is in seconds (see caveat)   
- start the webserver ./redis-live.py  
- RedisLive is now running @ http://localhost:8888/index.html
