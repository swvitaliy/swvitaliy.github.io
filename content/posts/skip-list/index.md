+++
title = 'Skip-list'
date = 2024-01-14T08:07:07+04:00
tags = [ "dsa", "skip-list", "go" ]

draft = true
+++

Skip-list - это вероятностная структура данных, которая похожа по функционалу сбалансированные деревья, однако отличается от них тем, помимо представления данных, что не имеет явного этапа балансировки. Вместо этого в момент вставки нового элемента мы выбираем длину списка ссылок (а значит пропусков) случайным образом. Поэтому статистически при большом количестве вставок поиск по этой структуре данных работает за log(N), как и операции вставки и удаления, которые содержат в себе поиск.

## Описание структуры данных

Каждый узел представляет из себя узел связного списка за исключением того, что вместо указателя `Next` на следующий элемент есть массив таких указателей. Поскольку размер этого массива является вероятностной величиной он ограничен определенным значением.

```go
const (  
    p        = 0.5
    maxLevel = 16
)  
  
type Key cmp.Ordered  
type Value any

type Node[K Key, V Value] struct {  
    key   K  
    value V  
    next  []*Node[K, V]  
}
```

При создании узла ему выделяется рандомное значение от 1 до `maxLevel`:

```go
func randomLevel() uint64 {  
    var lvl uint64 = 1  
    for rand.Float64() < 0.5 && lvl < maxLevel {  
       lvl++  
    }  
    return lvl  
}
```

Отдельно нужно хранить номер верхнего уровня для всей структуры `SkipList`:

```go
type SkipList[K Key, V Value] struct {  
    level uint64  
    head  *Node[K, V]  
}
```

## Принципы работы

### Поиск

Поиск выполняется в операциях удаления и вставки, поэтому сначала имеет смысл разобрать его.
При поиске элемента мы начинаем с верхнего уровня ссылок, переходя от элемента к элементу на этом уровне до тех пор пока не наткнемся на нулевой указатель или на подходящий элемент (больший или равный искомому).

```go
func (sl *SkipList[K, V]) SearchNode(target K) *Node[K, V] {  
    node := sl.head  
    for i := sl.level - 1; i >= 0; i-- {  
       for node != nil && node.next[i].key < target {  
          node = node.next[i]
       }  
    }
```

Если элемент равен искомому, то возвращаем его. В противном случае, возвращаем нулевой указатель.

// TODO рисунок поиска

### Вставка

При вставке в skip-list сначала мы формируем путь поиска, по которому мы идем из head к искомому элементу.

```go
func (sl *SkipList[K, V]) Insert(key K, value V) *Node[K, V] {  
    update := make([]*Node[K, V], maxLevel)  
    node := sl.head  
    for i := sl.level - 1; i >= 0; i-- {  
       for node != nil && node.next[i].key < key {  
          node = node.next[i]  
       }  
       update[i] = node  
    }  
  
    if node == nil {  
       return nil  
    }
```

Если найден ключ равный искомому - обновляем значение и выходим

```go
node = node.next[0]  
if node != nil && node.key == key {  
    node.value = value  
    return node  
}
```

Создаем массив ссылок на элементы (на следующем шаге будем использовать ссылки `Next[i]` из них)

```go
lvl := randomLevel()  
if lvl > sl.level {
    for i := sl.level; i < lvl; i++ {  
       update[i] = sl.head  
    }  
    sl.level = lvl  
}
```

Создаем новый узел, ссылки из предыдущих элементов на следущие устанавливаем на этот новый узел. Ссылки на следующие элементы устанавливаем для этого нового узла

```go
newNode := &Node[K, V]{  
    key:   key,  
    value: value,  
    next:  make([]*Node[K, V], lvl),  
}  
for i := uint64(0); i < lvl; i++ {  
    newNode.next[i] = update[i].next[i]  
    update[i].next[i] = newNode  
}
```

// TODO рисунок вставки

### Удаление

При удалении нам так же как и при вставке нужно сначала найти удаляемый элемент и сформировать массив элементов, которые следует обновить

```go
func (sl *SkipList[K, V]) Delete(key K) bool {  
    update := make([]*Node[K, V], maxLevel)  
    node := sl.head  
    for i := sl.level - 1; i >= 0; i-- {  
       for node.next[i] != nil && node.next[i].key < key {  
          node = node.next[i]  
       }  
       update[i] = node  
    }  
  
    node = node.next[0]  
    if node == nil || node.key != key {  
       return false  
    }
```

Затем нужно обновить список ссылок предыдущих элементов на следущие

```go
for i := uint64(0); i < sl.level; i++ {  
    if update[i].next[i] != node {  
       break  
    }  
    update[i].next[i] = node.next[i]  
}
```

Затем нужно уменьшить верхний уровень, если он имеет нулевой указатель на следующий элемент

```go
for sl.level > 1 && sl.head.next[sl.level-1] == nil {  
    sl.level--
}
```

## Статистическое доказательство средней сложности log(N)

Статистическое доказательство средней сложности `log(N)` поиска.

## Concurrency

Поскольку в структуре skip list каждый уровень - это связный список, то в отличие от деревьев тут нет операции ребалансировки, затрагивающей все дерево. Вместо этого мы имеем локальные операции вставки и удаления, затрагивающие соседние узлы. Поэтому skip list хорошо подходит для lock-free алгоритмов.

При конкурентной реализации skip list используем атомарные указатели и соответствующие операции для них, а так же операцию CompareAndSwap.

## Маркер удаления

Для ускорения операции удаления можно применить оптимизацию - помечать удаляемый элемент маркером (lazy deletion). Добавим маркер удаления узла

```go
type Node struct {
	key     int
	forward []*atomic.Pointer[Node]
	marked  atomic.Bool // true если логически удалён
}
```

Тогда в операции поиска необходимо проверить этот флаг

```go
next := curr.forward[0].Load()
if next != nil && next.key == key && !next.marked.Load() {
	return next, true
}
return nil, false

```

Для операции вставки необходимо проверить ситуацию, когда ключи совпадают
* если ключ уже есть и не помечен, то ничего не делает
* если ключ есть, но `marked == true`, - просто снимает флаг (`marked = false`)
* иначе вставляет новый узел так же, как и в не конкурентной реализации (только используются атомарные операции)

```go
next := curr.forward[0].Load()
if next != nil && next.key == key {
	if !next.marked.Load() {
		return false
	}
	next.marked.Store(false)
	return true
}
```


В операции удаления мы не удаляем, а помечаем элемент как удаленный. При этом должен быть с какой-то периодичностью (или по времени или по частоте запуска) процесс очистки маркеров.

```go
func (sl *SkipList) Compact() {
    for level := int(atomic.LoadInt32(&sl.level)) - 1; level >= 0; level-- {
        prev := sl.head
        curr := prev.forward[level].Load()

        for curr != nil {
            next := curr.forward[level].Load()

            if curr.marked.Load() {
                if prev.forward[level].CompareAndSwap(curr, next) {
                    curr = next
                    continue
                } else {
                    curr = prev.forward[level].Load()
                    continue
                }
            }

            prev = curr
            curr = next
        }
    }
}
```

// TODO рисунок

## Bulk operations

### BulkInsert

Можно отсортировать входные данные, если они не были отсортированы, и построить skip-list за `O(N)` (сложность в совокупности - сложность сортировки):

```go
func (sl *SkipList) BulkInsert(sortedKeys []int) {
    // Уровень каждого элемента можно назначить заранее
    nodes := make([]*Node, len(sortedKeys))
    for i, k := range sortedKeys {
        h := randomHeight()
        nodes[i] = &Node{key: k, forward: make([]*atomic.Pointer[Node], h)}
    }

    // Для каждого уровня соединяем узлы линейно
    for level := 0; level < maxLevel; level++ {
        var prev *Node = sl.head
        for _, n := range nodes {
            if level < len(n.forward) {
                prev.forward[level].Store(n)
                prev = n
            }
        }
        prev.forward[level].Store(nil)
    }

    atomic.StoreInt32(&sl.level, int32(maxLevel))
}
```

### RangeDelete

Если нужно удалить диапазон `[low, high]`,  
можно пройти один раз от `FindGE(low)` до `> high` и пометить всё:

```go
func (sl *SkipList) BulkDeleteRange(low, high int) {
    node, _ := sl.findGE(low)
    for node != nil && node.key <= high {
        node.marked.Store(true)
        node = node.forward[0].Load()
    }
}
```

Операция `FindGE`:

```go
func (sl *SkipList) FindGE(key int) *Node {
    curr := sl.head

    for level := int(atomic.LoadInt32(&sl.level)) - 1; level >= 0; level-- {
        next := curr.forward[level].Load()

        for next != nil && next.key < key {
            curr = next
            next = curr.forward[level].Load()
        }
    }

    next := curr.forward[0].Load() // next == nil || next.Key >= key

    for next != nil && next.marked.Load() {
        next = next.forward[0].Load()
    }

    return next
}
```

### BatchedDelete

Если ключи неупорядочены:

1. Сначала отсортировать ключи
2. Проходить список один раз, параллельно с массивом ключей

Это превращает `K x log N` поисков в один линейный проход O(N + K) + сортировка ключей `K log K`.

// TODO реализовать BatchedDelete

### BulkSearch

Массовые запросы (например, `SearchMany(keys)`) могут разделять общий путь поиска и не начинать с головы каждый раз.

// TODO реализовать SearchMany

### Shared Traversal

1. Для каждого `key` — продолжаем поиск с предыдущего найденного узла
2. Так каждый элемент ищет в среднем `O(log(N/K))` вместо `O(log N)`

Достигается **почти линейное время** при отсортированных ключах.

```go
func (sl *SkipList) BulkSearch(sortedKeys []int) []*Node {
    results := make([]*Node, len(sortedKeys))
    curr := sl.head
    for i, key := range sortedKeys {
        for level := sl.level - 1; level >= 0; level-- {
            for next := curr.forward[level].Load(); next != nil && next.key < key; {
                curr = next
                next = curr.forward[level].Load()
            }
        }
        cand := curr.forward[0].Load()
        if cand != nil && cand.key == key && !cand.marked.Load() {
            results[i] = cand
        }
    }
    return results
}
```

### SIMD / prefetch

В CPU-ориентированных реализациях (например, Redis или ClickHouse):
- при поиске батчей ключей можно использовать **prefetch** инструкцию CPU,
- заранее подгружая cache line для следующего узла (особенно на уровне 0).

// TODO Реализация SIMD / prefetch оптимизации

### Композиционные оптимизации

- **Batch-friendly random level generator** — использовать предсказуемые высоты для соседних ключей, чтобы структура оставалась статистически ровной при bulk вставке.
  
  // TODO Batch-friendly random level generator
      
- **Параллельные батчи** — если ключи не пересекаются, можно делить диапазоны на потоки.
  
- **Immutable bulk merge** — при массовом добавлении лучше построить новый skip list и потом атомарно заменить указатель на голову (copy-on-write подход).

## Применение

1. Redis `ZSET` - range запросы
2. RocksDB’s `MemTable`
3. ClickHouse
4. Java `ConcurrentSkipListMap`

// TODO Добавить ссылок на реализации


----

* [Реализация скип-листов на гитхаб](https://github.com/swvitaliy/goalgo/blob/main/skip_list/skip_list.go)
* Benchmarks

---
## References

1. https://www.math.umd.edu/~immortal/CMSC420/notes/skiplists.pdf
2. https://15721.courses.cs.cmu.edu/spring2018/papers/08-oltpindexes1/pugh-skiplists-cacm1990.pdf
3. https://www.cs.yale.edu/homes/aspnes/papers/opodis2005-b-trees.pdf
4. https://opendsa-server.cs.vt.edu/ODSA/Books/CS3/html/SkipList.html
5. https://arxiv.org/abs/2102.01044
6. https://habr.com/ru/articles/230413/
7. https://www.ietf.org/archive/id/draft-ietf-bess-weighted-hrw-00.html#name-weighted-hrw-and-its-applicat

