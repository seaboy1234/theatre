import unit_threaded;

import theatre.unittests;

int main(string[] args)
{
    return args.runTests!(
                          theatre.unittests
                          );
}
