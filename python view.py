import pygame
pygame.init()
screen = pygame.display.set_mode((640, 480))
pygame.display.set_caption("VGA Simulation")
screen.fill((0, 0, 0))
count = 0
errors = 0
with open("D:/2026_test/IFDP/IFDP.sim/sim_1/behav/xsim/pixels.txt") as f:
    for line in f:
        line = line.strip()
        if not line: continue
        parts = line.split(",")
        if len(parts) != 5: continue
        try:
            x,y,r,g,b = int(parts[0]),int(parts[1]),int(parts[2]),int(parts[3]),int(parts[4])
        except ValueError:
            errors += 1
            continue   # skip X/unknown values instead of crashing
        if 0 <= x < 640 and 0 <= y < 480:
            screen.set_at((x,y),(r*16,g*16,b*16))
            count += 1

print(f"Drew {count} pixels, skipped {errors} bad values")
if errors > 0:
    print("WARNING: X values found — bg_rom.hex probably wasn't loaded!")
    print("Check that bg_rom.hex is in the xsim run directory.")
pygame.display.flip()
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT: running = False
pygame.quit()