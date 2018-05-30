#ifndef DISPLAYH
#define DISPLAYH

#define WIDTH       1024
#define HEIGHT      864

// Тип отображения дампа памяти
#define DUMP_ZP     1
#define DUMP_STACK  2

// 1 пиксель на экране
struct sRGB {
    
    unsigned char r;
    unsigned char g;
    unsigned char b;
    
};

// Глобальная палитра
struct sRGB globalPalette[ 64 ];

// RGB x ScanlineY x ScanlineX
struct sRGB frame[ HEIGHT ][ WIDTH ];

// Режим отображения дампа памяти
char dump_mode;

// Спрайты
unsigned char   ctrl0;
unsigned char   ctrl1;
unsigned char   spraddr;
unsigned char   objvar;
int             sprite[256];
int             video_scroll;
unsigned char   ppu_status;

// Прототипы 
// ---------------------------------------------------------------------

void setBigPixel(int, int, int);
void printString(int, int, char*, int, int);
void printHex(int, int, unsigned int, int, int, int);
void drawLine(int, int, int, int, int);
void printScreen();
void printRegisters();
void display();
void fontsLoad();
int initGlobalPal();
void setPalette(int, int, int, int);

#endif
