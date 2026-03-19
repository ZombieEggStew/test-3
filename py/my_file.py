class my_file:
    def __init__(self, path):
        self.path = path
        self.name = path.split('/')[-1]

    def get_name(self):
        return self.name
    
    def get_path(self):
        return self.path