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

// Функция рисования треугольника через линии по алгоритму Брезенхэма
// Преимущества: работает с целыми числами и точнее
// Недостатки:   не так просто отрезать верхнюю невидимую область

void trif(struct point2d np[], uint color) {
    
    int i, j, k;
    struct point2d p[3], pt;
    
    // Сортировка точек по возрастанию Y
    for (i = 0; i < 3; i++) p[i] = np[i];
    for (i = 0; i < 3; i++) {
        for (j = i + 1; j < 3; j++) {
            if (p[i].y > p[j].y) { pt = p[i]; p[i] = p[j]; p[j] = pt; }
        }
    }
    
    // Общая линия AC
    int acsx = p[0].x < p[2].x ? 1 : -1; // Приращение X (-1, 1)
    int acdx = p[2].x > p[0].x ? p[2].x - p[0].x : p[0].x - p[2].x; // = abs(C.x - A.x)
    int acdy = p[2].y > p[0].y ? p[2].y - p[0].y : p[0].y - p[2].y; // = abs(C.y - A.y)
    int acerror = acdx - acdy;           // Дельта ошибки
    int acerror2, aberror2;    
    int acx = p[0].x,     
        acy = p[0].y;
    
    // Поставим точку
    pset(acx, acy, color);
    
    // Два полутреугольника
    for (i = 0; i < 2; i++) {
        
        // Линия полутреугольника AB
        int absx = p[i  ].x < p[i+1].x ? 1 : -1;
        int abdx = p[i+1].x > p[i].x ? p[i+1].x - p[i].x : p[i].x - p[i+1].x; // = abs(B.x - A.x) либо abs(C.x - B.x)
        int abdy = p[i+1].y > p[i].y ? p[i+1].y - p[i].y : p[i].y - p[i+1].y; // = abs(B.y - A.y) либо abs(C.y - B.y)
        int aberror = abdx - abdy; // Дельта
        int abx = p[i].x, 
            aby = p[i].y;
        
        for (j = p[i].y; j < p[i+1].y; j++) {
                    
            while (1) { // AC: Искать первый Y+1
                            
                acerror2 = 2 * acerror;
                if (acerror2 > -acdy) { acerror -= acdy; acx += acsx; }
                if (acerror2 < acdx)  { acerror += acdx; acy += 1; break; }
            }

            while (1) { // AB, BC: Искать первый Y+1
                            
                aberror2 = 2 * aberror;
                if (aberror2 > -abdy) { aberror -= abdy; abx += absx; }
                if (aberror2 <  abdx) { aberror += abdx; aby += 1; break; }
            }
            
            // Невидимая линия за верхней частью экрана
            if (acy < 0) continue;

            // Сортировка x1, x2
            int x1 = abx < acx ? abx : acx;
            int x2 = abx < acx ? acx : abx;

            // Рисование линии не за экраном и в правильном порядке
            if (acy > SCREEN_H) return;
            if (x1 < 0) x1 = 0;
            if (x2 >= SCREEN_W) x2 = SCREEN_W - 1;
            if (x1 >= SCREEN_W) continue;
            if (x2 < 0) continue;
            
            // Рисование сплошной линии в треугольнике
            for (k = x1; k <= x2; k++) pset(k, acy, color);
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
