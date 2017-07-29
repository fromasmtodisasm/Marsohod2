// Процедура скачивания небольших текстовых файлов
function download(filename, text) {
   
    // Создать ссылку и назначить ей атрибуты
    var element = document.createElement('a');
    element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
    element.setAttribute('download', filename);
    element.style.display = 'none';
    
    // Приплюсовать к Body
    document.body.appendChild(element);

    // Имитировать нажатие
    element.click();
    
    // Удалить элеменет
    document.body.removeChild(element);
}
