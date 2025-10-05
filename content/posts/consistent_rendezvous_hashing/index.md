+++
title = 'Consistetent hasing and Rendezvous hashing (HRW)'
date = 2025-08-17T10:00:00+04:00
tags = [ "dsa", "consistent", "rendezvous", "hashing", "go" ]

draft = true
+++

## Rendezvous hashing

Rendezvous hashing (**HRW - Highest Random Weight hashing**) - это алгоритм взятия хеша, который стремится минимизировать изменение в распределении потребителей узлов (подписчиков, клиентов) при увеличении/уменьшении их числа.

На вход этому алгоритму поступает какое-то число (заранее взятый быстрый хеш, вроде murmur3, xxhash) и количество бакетов (узлов, шардов и так далее). Данный алгоритм  ставит в соответствие переданное число `n` в бакет под номером `k`, причем делает это таким образом, что при изменении числа бакетов соответствие переданного числа бакету стремиться не меняться. Данный алгоритм не использует ring key buffer, в отличие от консистентного хеша.


При использовании rendezvous hash примерно 1/N ключей будут перераспределены при добавлении/удалении ключа. В случае с consistent hash это примерно 10-15%.

## WRH - Weighted Rendezvous Hashing


 
## Применение

1. redis-go для выбора узла в shardedClient
2. nginx
3. 


----

## Referencies

1. https://medium.com/my-games-company/comparing-consistent-vs-rendezvous-hashing-for-hashing-server-data-9e90dfe51740
2. https://habr.com/ru/companies/mygames/articles/669390/
3. https://randorithms.com/2020/12/26/rendezvous-hashing.html
4. https://pvk.ca/Blog/2017/09/24/rendezvous-hashing-my-baseline-consistent-distribution-method/
5. https://www.eecs.umich.edu/techreports/cse/96/CSE-TR-316-96.pdf
6. https://github.com/dgryski/go-rendezvous/blob/master/rdv.go
7. 
