#include <nvboard.h>
#include <Vtop.h>

static TOP_NAME dut;

void nvboard_bind_all_pins(TOP_NAME* top);

static void single_cycle() {
  dut.clk = 0; dut.eval();
  dut.clk = 1; dut.eval();
}

static void reset(int n) {
  dut.rst = 1;
  while (n -- > 0) single_cycle();
  dut.rst = 0;
}

extern void kb_print_scancode();

int main() {
  nvboard_bind_all_pins(&dut);
  nvboard_init();

  reset(10);

  while(1) {
    nvboard_update();
    single_cycle();

  if (dut.processed_key_pressed_debug) {
      printf("key_count: %d, processed_key_code: 0x%02x, ascii_code: 0x%02x\n", 
            dut.key_count_debug, dut.processed_key_code_debug, dut.ascii_code_debug);
  }    
  }
}
