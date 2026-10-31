+++
title = 'Count-Min Sketch, HyperLogLog'
date = 2025-11-02T10:00:00+04:00
tags = [ "CMS", "count-min sketch", "HLL", "HyperLogLog" ]

draft = true
+++

## HyperLogLog



## CMS and bloom-filter

### Count-Min Sketch Algorithm

Count-Min Sketch - вероятностный алгоритм подсчета уникальных элементов, когда этих уникальных элементов большое количество и нет возможности поместить их всех в память. При этом можно посчитать с определенной точностью, например, 95 или 99%.

К числу таких задач относятся подсчет количества просмотров видео на youtube, количество уникальных пользователей на сайте, количество обращений по ключу к кешу и многое другое.

// TODO Кто его придумал?

Данный алгоритм придуман в google в 2004-м году и имеет широкое применение, ввиду его эфективности, простоты понимания и практической пользы.

### Реализация 

Реализация CMS довольно простая. Для подсчета по ключу мы будем считать не по самому ключу, а по его хешу. Точнее не по одному хешу, на по нескольким. Таким образом, для хранения количества нам потребуется K\*N памяти, где K - количество хеш-функций, N - размер таблицы для хранения значений хешей. Разумеется, при вычислении хешей мы будем иметь коллизии и за счет этого будем имет число большее, чем есть на самом деле, но, за счет того, что есть несколько хеш фенкций мы накапливаем точность (берем min среди значений кешей).

```go
type CMS struct {
	data   [][]uint64
	width  uint64
	hashes []func([]byte) uint64
}

func MakeHash(seed uint64) func(data []byte) uint64 {
	return func(data []byte) uint64 {
		digest := xxhash.NewWithSeed(seed)
		_, _ = digest.Write(data)
		return digest.Sum64()
	}
}

func NewCMS(width uint64, hashes []func([]byte) uint64) *CMS {
	data := make([][]uint64, len(hashes))
	for i := range data {
		data[i] = make([]uint64, width)
	}
	return &CMS{
		data:   data,
		width:  width,
		hashes: hashes,
	}
}

func (cms *CMS) Add(data []byte) {
	for i, h := range cms.hashes {
		index := h(data) % cms.width
		cms.data[i][index]++
	}
}

****
```

### Расчет точности




### Реализация в redis



### Benchmark

Замеры точности

1 текст (wap)
меняем ширину и смотрим на девиацию 
- 100
- 1k
- 10k

