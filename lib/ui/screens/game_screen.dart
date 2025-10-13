body: Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${widget.playerName}'s turn",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const CircularProgressIndicator(
              color: Colors.amber,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
      Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 8,
                color: Colors.white70,
                child: SizedBox(
                    height: 140,
                    width: 100,
                    child: Center(
                        child: Text(
                      "5♦️",
                      style: TextStyle(
                          fontSize: 28, color: Colors.red.shade700),
                    ))),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Text("Draw Card"),
              ),
              const SizedBox(height: 20),
              Text("Draw Pile: 46",
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.black26,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text("Player hand goes here",
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    ],
  ),
),