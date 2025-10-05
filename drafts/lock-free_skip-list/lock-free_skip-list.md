# Lock-free skip-list


## Примечание

Как показано в [3]() при количестве ядер до 8 оптимизации хорошо себя показывают и skip-list c блокировками работает не хуже (а на малом количестве ядер даже лучше), чем lock-free реализация. Интересно было бы посмотреть на бенчмарки при 16/32/64 ядрах... (aws graviton)


## References
2. [Jiffy: A Lock-free Skip List with Batch Updates and Snapshots](https://arxiv.org/abs/2102.01044)
3. https://supertaunt.github.io/CMU_15618_project.github.io/