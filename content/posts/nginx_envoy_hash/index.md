+++
title = 'nginx vs envoy hash algorithms'
date = 2025-08-17T10:00:00+04:00
tags = [ "nginx", "envoy", "consistent hashing" ]

draft = true
+++


## nginx hash

Рассмотрим реализацию команды `hash $something;` в nginx.

Реализация команды hash находится в модуле [ngx_http_upstream_hash_module](https://github.com/nginx/nginx/blob/master/src/http/modules/ngx_http_upstream_hash_module.c). Ключевая функция получения сервера (peer) `ngx_http_upstream_get_hash_peer`. В данной функции реализованы алгоритмы weighted round robin + retries + fallback to round robin w\o weights. Рассмотрим код данной функции, который отвечает за выбор узла.


```c
 for ( ;; ) {

        /*
         * Hash expression is compatible with Cache::Memcached:
         * ((crc32([REHASH] KEY) >> 16) & 0x7fff) + PREV_HASH
         * with REHASH omitted at the first iteration.
         */

        ngx_crc32_init(hash);

        if (hp->rehash > 0) {
            size = ngx_sprintf(buf, "%ui", hp->rehash) - buf;
            ngx_crc32_update(&hash, buf, size);
        }

        ngx_crc32_update(&hash, hp->key.data, hp->key.len);
        ngx_crc32_final(hash);

        hash = (hash >> 16) & 0x7fff;

        hp->hash += hash;
        hp->rehash++;

        w = hp->hash % hp->rrp.peers->total_weight;
        peer = hp->rrp.peers->peer;
        p = 0;

        while (w >= peer->weight) {
            w -= peer->weight;
            peer = peer->next;
            p++;
        }

        n = p / (8 * sizeof(uintptr_t));
        m = (uintptr_t) 1 << p % (8 * sizeof(uintptr_t));

        if (hp->rrp.tried[n] & m) {
            goto next;
        }

        ngx_http_upstream_rr_peer_lock(hp->rrp.peers, peer);

        ngx_log_debug2(NGX_LOG_DEBUG_HTTP, pc->log, 0,
                       "get hash peer, value:%uD, peer:%ui", hp->hash, p);

        if (peer->down) {
            ngx_http_upstream_rr_peer_unlock(hp->rrp.peers, peer);
            goto next;
        }

        if (peer->max_fails
            && peer->fails >= peer->max_fails
            && now - peer->checked <= peer->fail_timeout)
        {
            ngx_http_upstream_rr_peer_unlock(hp->rrp.peers, peer);
            goto next;
        }

        if (peer->max_conns && peer->conns >= peer->max_conns) {
            ngx_http_upstream_rr_peer_unlock(hp->rrp.peers, peer);
            goto next;
        }

        break;

    next:

        if (++hp->tries > 20) {
            ngx_http_upstream_rr_peers_unlock(hp->rrp.peers);
            return hp->get_rr_peer(pc, &hp->rrp);
        }
    }
```

В данном коде происходит 20 попыток получить peer по ключу. Если количество попыток превысило 20, то берем по простому round robin. 

В первых строках происходит вычисление хеша через crc32. Для каждой попытки к хешируемым данным добавляется индекс попытки (hp->rehash) за исключением первой.

После вычисления хеша текущей попытки он добавляется к общему хешу. Это, насколько я понимаю, делает выбор более равномерным.

Берем модуль хеша от суммарного веса всех узлов и получаем случайную точку w от 0 до total_weight-1:

```c
w = hp->hash % hp->rrp.peers->total_weight;
```

Далее выполняется weighted round robin:

```c
        peer = hp->rrp.peers->peer;
        p = 0;

        while (w >= peer->weight) {
            w -= peer->weight;
            peer = peer->next;
            p++;
        }
```

В данном коде мы последовательно обходим peers в связном списке и проверяем каждый на 

// TODO тут он ходит последовательно по связному списку - как обеспечивается равные шансы на получение узла, если у всех веса одинаковые

Затем, мы смотрим, если мы этот сервер уже пробовали, чтобы не ходить к него снова (битовая магия):

```c
	n = p / (8 * sizeof(uintptr_t));  
	m = (uintptr_t) 1 << p % (8 * sizeof(uintptr_t));  
	  
	if (hp->rrp.tried[n] & m) {  
		goto next;  
	}
```

В следующих строках происходит несколько проверок

// TODO описание магии битовой карты tried

Использование randezvous алгоритма при выборе узла, на мой взгляд, при реализации директивы `hash consistent` в nginx оправдано, поскольку мы редактируем список узлов руками, из-за этого он не можем быть очень большим и применение hash ring в данном случае привело бы к необходимости хранить его и усложнило бы процесс выбора. Однако, есть несколько нюансов реализации, которые могут ограничить область применения данной команды и о которых, на мой взгляд, было бы полезно знать.

## Нюансы реализации команды nginx hash

Есть несколько интересных моментов реализации детерминированного хеширования в модуле `ngx_http_upstream_hash_module`. 

Во-первых, при использовании директивы hash, если количество попыток взять сервер по hash превышает 20, то мы выбираем сервер по round robin. Вероятно, этот fallback сделан для обеспечения доступности в угоду правильности работы алгоритма. При этом нет никакой ручки, чтобы понять, что он выбрал не ту ноду. Такой trade-off, на мой взгляд, не позволяет применять данный модуль для систем, для которых нужна строгая гарантия отправки запроса на нужный узел. Например, для систем, которые хранят часть своего состояния относящегося к клиенту на узлах. Так же, кажется, не получится сделать какой-то самостоятельный механизм поиска нужного узла, поскольку данный модуль (а возможно и nginx в целом) не предполагает, что вы можете отправить обратный запрос. Это ограничивает применение данной команды для случая использования кешей на backend серверах, когда переход не в тот узел не приведет к нарушению работы системы.

Не менее важный момент не относится непосредственно реализации алгоритма рандеву, но затрагивает его. Если мы используем директиву `server any... resolve`, в которой содержится dns адрес, возвращающий несколько ip, то при изменении списка узлов, например, при изменении его порядка (dns не гарантирует порядок), мы получим другое распределение. При указании resolve периодически выполняется `ngx_http_upstream_resolve_handler`, описанный в файле [ngx_http_upstream.c](https://github.com/nginx/nginx/blob/master/src/http/ngx_http_upstream.c#L1222) . Туда уже передается список адресов, после чего вызывается функция `ngx_http_upstream_create_round_robin_peer` - по этому списку происходит обход в цикле, в котором инициализируется массив `peer`:

```c
    ngx_http_upstream_resolved_t  *ur
    ...
    ur->naddrs = ctx->naddrs;
    ur->addrs = ctx->addrs;
	...
	if (ngx_http_upstream_create_round_robin_peer(r, ur) != NGX_OK) {
        ngx_http_upstream_finalize_request(r, u,
                                           NGX_HTTP_INTERNAL_SERVER_ERROR);
        goto failed;
    }
```

```c
for (i = 0; i < ur->naddrs; i++) {
...
	peer[i].sockaddr = sockaddr;
	peer[i].socklen = socklen;
	peer[i].name.len = len;
	peer[i].name.data = p;
	peer[i].weight = 1;
	peer[i].effective_weight = 1;
	peer[i].current_weight = 0;
	peer[i].max_conns = 0;
	peer[i].max_fails = 1;
	peer[i].fail_timeout = 10;
}

```

ctx->naddrs в ngx_http_upstream_resolve_handler берется из функции `ngx_resolver_process_a` в файле `src/core/ngx_resolver.c` (для AAA записей есть аналогичная функция), в которой так же сохраняется тот порядок адресов, который был передан от dns сервера:

```c
static void  
ngx_resolver_process_a(ngx_resolver_t *r, ngx_resolver_ctx_t *ctx, ...)  
{
	ctx->addrs = ngx_resolver_alloc(r, naddrs * sizeof(ngx_resolver_addr_t));  
  
	for (i = 0; i < naddrs; i++) {
		ctx->addrs[i].sockaddr = ...;  
		ctx->addrs[i].socklen = ...;  
		ctx->addrs[i].name = ...;  
	}
}
```


## nginx hash consistent

Рассмотрим реализацию команды `hash $something consistent;` в nginx. Данная команда выполняет consistent hashing.