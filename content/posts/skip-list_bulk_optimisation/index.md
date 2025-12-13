+++
title = 'Skip-list bulk operations'
date = 2024-01-14T08:07:07+04:00
tags = [ "dsa", "skip-list", "go" ]

draft = true
+++
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

## Jitty

https://arxiv.org/abs/2102.01044#
