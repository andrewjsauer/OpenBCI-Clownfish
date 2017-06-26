

//////////////////////////////////////////////////////////////
//
// This class creates and manages the messaging to a toy
//
// Created: Chip Audette, May-June 2014
// Modified: Andrew Sauer, June 2017
//
///////////////////////////////////////////////////////////////

class Toy {

   private int wait_millis = 5;

  //create inner class to wrap up a "command"
  class Command {
    private String command_str;
    private String name;
    private int counter;
    private Serial serial_h;
    public boolean printReceivedCommand = false;
    public int ID;

    Command(Serial _serial_h, String _str, String _name, int _ID) {
      serial_h = _serial_h;
      command_str = _str;
      name =_name;
      counter = 0;
      ID = _ID;
    }

    public int issue() {
      counter++;
      if (printReceivedCommand) println("Toy: Command: " + name + " (" + counter + ")");
      if (serial_h != null) serial_h.write(command_str);
      return ID;
    }
  } //close definition of class Command

  private Command command_forward, command_climb, command_dive, command_left, command_right;
  private int prev_command = -1;

  //Constructor, pass in an already-opened serial port
  Toy (Serial serialPort) {
    int ID = 0;
    command_forward = new Command(serialPort,"O","Swim!",ID++);
    command_right = new Command(serialPort,"|","Right",ID++);
    command_left = new Command(serialPort,"{","Left",ID++);
    command_climb = new Command(serialPort,"}","Climb",ID++);
    command_dive = new Command(serialPort,"P","Dive",ID++);
  }

  public void climb() {
    prev_command = command_climb.issue();
  }
  public void dive() {
    prev_command = command_dive.issue();
  }
  public void forward() {
    prev_command = command_forward.issue();
  }
  public void left() {
    prev_command = command_left.issue();
  }
  public void right() {
    prev_command = command_right.issue();
  }

  public void waitMilliseconds(int dt_millis) {
      int start_time = millis();
      int t = millis();
      while (t-start_time < dt_millis) {
        t = millis();
      }
  }

}
