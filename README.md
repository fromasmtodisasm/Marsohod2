# Marsohod2

Эталон для реализации проектов на плате Марсоход-2
<pre>
Файл проекта:       marsohod2.qpf
Параметры проекта:  marsohod2.qsf
Top-Level Entity:   marsohod2.v
Waveform File:      marsohod2.vwf
</pre>
Размечены пины под всю периферию (78 пинов)

# Проекты

Представлены различные мои проекты, для собственного интереса. Какой должен быть .gitignore для каждого проекта, находится в папке src

# Как развернуть новый проект

1. Скопировать из папки src/ в папку projects/<имя_проекта>/ либо в другую папку
2. Скопировать icarus в testbench/ папку в папке проекта
3. Использовать component/<нужный компонент> в файле Marsohod2.v 

    - добавить сам компонент в корень проекта
    - использовать информацию из about.v для включения в код проекта
    