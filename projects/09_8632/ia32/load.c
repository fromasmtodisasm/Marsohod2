void preload(int argc, char* argv[]) {
    
    FILE* f = fopen("bios.bin", "r");
    if (f == NULL) {
        
        printf("bios.bin not found");
        exit(1);
    }
    
    fread(RAM, 1, 65536, f);
    
    fclose(f);
    
}
