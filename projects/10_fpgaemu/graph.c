// Размеры окна
#define SCREEN_W    1280 // 640 x 2
#define SCREEN_H    800  // 400 x 2

SDL_Surface * sdl_screen;

void init_graphics() {
    sdl_screen = SDL_SetVideoMode(SCREEN_W, SCREEN_H, 32, SDL_HWSURFACE | SDL_DOUBLEBUF);
    SDL_WM_SetCaption( "Симулятор ПЛИС Cyclone III", 0 );
}

// Рисуем точку
void pset(int x, int y, uint color) {
    if (x >= 0 && x < SCREEN_W && y >= 0 && y < SCREEN_H) {
        ( (Uint32*)sdl_screen->pixels )[ x + SCREEN_W*y ] = color;
    }
}

// Рисуем закрашенный прямоугольник на экране
void blockf(int x1, int y1, int x2, int y2, uint color) {

    int x, y;
    for (y = y1; y <= y2; y++) {
        for (x = x1; x <= x2; x++) {
            pset(x, y, color);
        }
    }
}

// Незакрашенный прямоугольник
void block(int x1, int y1, int x2, int y2, uint color) {

    int i;

    // Горизонтальные линии
    for (i = x1; i <= x2; i++) {
        pset(i, y1, color);
        pset(i, y2, color);
    }

    // Вертикальные линии
    for (i = y1; i <= y2; i++) {
        pset(x1, i, color);
        pset(x2, i, color);
    }

}

// Рисование линии по алгоритму Брезенхема
// https://ru.wikipedia.org/wiki/Алгоритм_Брезенхэма
void line(int x1, int y1, int x2, int y2, uint color) {

    // Инициализация смещений
    int signx  = x1 < x2 ? 1 : -1;
    int signy  = y1 < y2 ? 1 : -1;
    int deltax = x2 > x1 ? x2 - x1 : x1 - x2;
    int deltay = y2 > y1 ? y2 - y1 : y1 - y2;
    int error  = deltax - deltay;
    int error2;

    // Если линия - это точка
    pset(x2, y2, color);    

    // Перебирать до конца
    while ((x1 != x2) || (y1 != y2)) {

        pset(x1, y1, color);
        error2 = 2 * error;
        
        // Коррекция по X
        if (error2 > -deltay) {
            error -= deltay;
            x1 += signx;
        }
        
        // Коррекция по Y
        if (error2 < deltax) {
            error += deltax;
            y1 += signy;
        }

    }
}

// Рисование окружности
void circle(int xc, int yc, int radius, uint color) {

    int x = 0,
        y = radius,
        d = 3 - 2*y;

    while (x <= y) {

        // Верхний и нижний сектор
        pset(xc - x, yc + y, color);
        pset(xc + x, yc + y, color);
        pset(xc - x, yc - y, color);
        pset(xc + x, yc - y, color);

        // Левый и правый сектор
        pset(xc - y, yc + x, color);
        pset(xc + y, yc + x, color);
        pset(xc - y, yc - x, color);
        pset(xc + y, yc - x, color);

        d += (4*x + 6);
        if (d >= 0) {
            d += 4*(1 - y);
            y--;
        }

        x++;
    }
}

// Рисование окружности
void circlef(int xc, int yc, int radius, uint color) {

    int x = 0,
        y = radius,
        d = 3 - 2*y;

    while (x <= y) {

        // Верхний и нижний сектор
        line(xc - x, yc + y, xc + x, yc + y, color);
        line(xc - x, yc - y, xc + x, yc - y, color);

        // Левый и правый сектор
        line(xc - y, yc + x, xc + y, yc + x, color);
        line(xc - y, yc - x, xc + y, yc - x, color);

        d += (4*x + 6);
        if (d >= 0) {
            d += 4*(1 - y);
            y--;
        }

        x++;
    }
}

// Рисование треугольника
void trianglef(int x1, int y1, int x2, int y2, int x3, int y3, uint color) {

    int i, j, k;
    struct point2d p[3], tp;

    // Массив для 3 точек для того, чтобы отсортировать их по Y
    p[0].x = x1; p[0].y = y1;
    p[1].x = x2; p[1].y = y2;
    p[2].x = x3; p[2].y = y3;

    // Сортировка по Y точек p[]
    for (i = 0; i < 3; i++) {
        for (j = i + 1; j < 3; j++) {
            if (p[i].y > p[j].y) {
                tp = p[i];
                p[i] = p[j];
                p[j] = tp;
            }
        }
    }

    if (p[2].y == p[0].y) {
        line(p[0].x, p[0].y, p[2].x, p[0].y, color);
        return;
    }

    // Инкрементирование x1-x3
    float ac  = (float)(p[2].x - p[0].x) / (float)(p[2].y - p[0].y);

    float xa  = (float)p[0].x;
    float xb  = (float)p[0].x;
    int   yi  = p[0].y;

    // Рисуем 2 треугольника

    // p[0].y -> p[1].y
    // p[1].y -> p[2].y

    for (i = 0; i < 2; i++) {

        int h = p[i+1].y - p[i].y;

        // Если полу-треугольник = линия
        if (p[i+1].y == p[i].y) {
            line((int)xa, p[i].y, (int)xb, p[i].y, color);
            continue;
        }

        // Расчет локального смещения на каждую линию (инкрементально)
        float ab = (float)(p[i+1].x - p[i].x) / (float)(p[i+1].y - p[i].y);

        // Полный треугольник за верхней частью экрана
        if (p[i+1].y < 0) {

            k   = p[i+1].y - p[i].y;
            yi += k;
            xa += k * ab;
            xb += k * ac;
            continue;
        }

        // Частично за верхней частью
        if (p[i].y < 0) {

            k   = -p[i].y;
            h  -= k;
            yi += k;
            xa += k * ab;
            xb += k * ac;
        }

        // Рисование горизонтальных линии на один полутреугольник
        for (j = 0; j < h; j++) {

            int x1i = (int)xa;
            int x2i = (int)xb;

            // Инкременты для рисования треугольника
            yi++;
            xa += ab;
            xb += ac;

            // Выход из цикла, если превысил высоту
            if (yi >= SCREEN_H) {
                break;
            }

            // xi1 будет <= x2i (слева направо)
            if (x1i > x2i) { k = x1i; x1i = x2i; x2i = k; }

            // Проверка условий на отрисовку
            if (x1i < 0) x1i = 0;                     // Левая часть за левой стороной экрана
            if (x2i >= SCREEN_W) x2i = SCREEN_W - 1;  // Правая часть за правой стороной экрана
            if (x1i >= SCREEN_W) continue;            // Левая часть за правой стороной
            if (x2i < 0) continue;                    // Правая часть за левой стороной

            line(x1i, yi, x2i, yi, color);
        }

        // Выход из цикла, если превысил высоту
        if (yi >= SCREEN_H) {
            break;
        }
    }
}

// Нарисовать букву
void printchar(int x, int y, char sym, uint color) {

    int i, j, ch;
    for (i = 0; i < 16; i++) {

        ch = font[ 16*sym + i ];
        for (j = 0; j < 8; j++)
            if (ch & (1 << j))
                pset(x + 7 - j, y + i, color);
    }
}

// Напечатать моноширинный текст / BIOS
void print(int x, int y, char* text, uint color) {

    char* s = text;
    while (*s) {

        printchar(x, y, *s, color);
        x += 8;
        s++;
    }

}

// Нарисовать экран
void flip() {
    SDL_Flip(sdl_screen);
}
